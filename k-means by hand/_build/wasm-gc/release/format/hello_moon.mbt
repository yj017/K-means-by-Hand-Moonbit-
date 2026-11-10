// Main package file for your library code.
// Put public APIs and shared helpers here.
// Keep blocks small and focused for easy refactors.

///|
pub(all) struct Point {
  coords : Array[Double]
}

///|
pub fn Point::dim(self : Point) -> Int32 {
  self.coords.length()
}

///|
pub fn squared_distance(a : Point, b : Point) -> Double {
  let mut sum = 0.0
  for i in 0..<a.dim() {
    let diff = a.coords[i] - b.coords[i]
    sum = sum + diff * diff
  }
  sum
}

///|
pub fn assign_labels(
  points : Array[Point],
  centroids : Array[Point],
) -> Array[Int32] {
  let labels = Array::make(points.length(), 0)
  for i in 0..<points.length() {
    let mut min_dist = squared_distance(points[i], centroids[0])
    let mut min_index = 0
    for k in 1..<centroids.length() {
      let d = squared_distance(points[i], centroids[k])
      if d < min_dist {
        min_dist = d
        min_index = k
      }
    }
    labels[i] = min_index
  }
  labels
}

///|
pub fn update_centroids(
  points : Array[Point],
  labels : Array[Int32],
  k : Int32,
  old_centroids : Array[Point],
) -> Array[Point] {
  let dim = old_centroids[0].dim()
  let new_centroids : Array[Point] = []
  for c in 0..<k {
    let sum = Array::make(dim, 0.0)
    let mut count = 0
    for i in 0..<points.length() {
      if labels[i] == c {
        for d in 0..<dim {
          sum[d] = sum[d] + points[i].coords[d]
        }
        count = count + 1
      }
    }
    if count == 0 {
      new_centroids.push(old_centroids[c])
    } else {
      let coords = Array::make(dim, 0.0)
      for d in 0..<dim {
        coords[d] = sum[d] / count.to_double()
      }
      new_centroids.push(Point::{ coords, })
    }
  }
  new_centroids
}

///|
pub fn init_centroids(points : Array[Point], k : Int32) -> Array[Point] {
  let r = @random.Rand()
  let indices = Array::make(points.length(), 0)
  for i in 0..<indices.length() {
    indices[i] = i
  }

  // 1. Array::shuffle 返回新数组，需要用变量接收
  // 2. r.int 的 limit 是命名参数，写成 limit=limit
  let shuffled = indices.shuffle(rand=fn(limit) { r.int(limit~) })

  let centroids : Array[Point] = []
  for i in 0..<k {
    centroids.push(points[shuffled[i]])
  }
  centroids
}

///|
pub fn total_shift_squared(
  old_centroids : Array[Point],
  new_centroids : Array[Point],
) -> Double {
  let mut sum = 0.0
  for c in 0..<old_centroids.length() {
    let dim = old_centroids[c].dim()
    for d in 0..<dim {
      let diff = new_centroids[c].coords[d] - old_centroids[c].coords[d]
      sum = sum + diff * diff
    }
  }
  sum
}

///|
pub fn kmeans(
  points : Array[Point],
  k : Int32,
  max_iters : Int32,
  tol : Double,
) -> (Array[Point], Array[Int32]) {
  let mut centroids = init_centroids_kmeanspp(points, k)
  let mut labels : Array[Int32] = []
  for _ in 0..<max_iters {
    labels = assign_labels(points, centroids)
    let new_centroids = update_centroids(points, labels, k, centroids)
    let shift = total_shift_squared(centroids, new_centroids)
    centroids = new_centroids
    if shift < tol * tol {
      break
    }
  }
  (centroids, labels)
}

///|
pub fn init_centroids_kmeanspp(
  points : Array[Point],
  k : Int32,
) -> Array[Point] {
  let r = @random.Rand()
  let n = points.length()
  let centroids : Array[Point] = []

  // 1. 第一个质心：均匀随机选一个点
  let first_idx = r.int(limit=n)
  centroids.push(points[first_idx])

  // 2. 迭代选择剩下的 k-1 个质心
  for _ in 1..<k {
    // 计算每个点的 D(x)^2（到最近已有质心的平方距离）
    let weights = Array::make(n, 0.0)
    let mut total_weight = 0.0
    for i in 0..<n {
      let mut min_dist = squared_distance(points[i], centroids[0])
      for c in 1..<centroids.length() {
        let d = squared_distance(points[i], centroids[c])
        if d < min_dist {
          min_dist = d
        }
      }
      weights[i] = min_dist
      total_weight = total_weight + min_dist
    }

    // 3. D² 采样：生成 [0, total_weight) 的随机数，按累积权重选中一个点
    let r_val = r.double() * total_weight // 假设存在 double(limit) 方法
    let mut cumulative = 0.0
    let mut chosen_idx = 0
    for i in 0..<n {
      cumulative = cumulative + weights[i]
      if cumulative > r_val {
        chosen_idx = i
        break
      }
    }
    centroids.push(points[chosen_idx])
  }

  centroids
}

///|
test "kmeans++: 三个质心分属三个不同的团" {
  let points = [
    // 左上团
    Point::{ coords: [1.0, 2.0], },
    Point::{ coords: [1.5, 1.8], },
    Point::{ coords: [1.2, 1.6], },
    // 右上团
    Point::{ coords: [5.0, 8.0], },
    Point::{ coords: [5.5, 7.8], },
    Point::{ coords: [5.2, 8.2], },
    // 左下团
    Point::{ coords: [1.0, 0.6], },
    Point::{ coords: [1.3, 0.4], },
    Point::{ coords: [0.8, 0.5], },
  ]
  let centroids = init_centroids_kmeanspp(points, 3)
  assert_eq(centroids.length(), 3)

  // 用坐标判断质心属于哪个团：
  // 右上团: x > 3.0
  // 左上团: x <= 3.0 且 y > 1.0
  // 左下团: x <= 3.0 且 y <= 1.0
  let group_ids : Array[Int32] = []
  for c in 0..<centroids.length() {
    let x = centroids[c].coords[0]
    let y = centroids[c].coords[1]
    let gid = if x > 3.0 {
      1 // 右上
    } else if y > 1.0 {
      0 // 左上
    } else {
      2 // 左下
    }
    group_ids.push(gid)
  }

  // 三个质心必须分属三个不同的团
  assert_eq(group_ids[0] != group_ids[1], true)
  assert_eq(group_ids[0] != group_ids[2], true)
  assert_eq(group_ids[1] != group_ids[2], true)
}

///|
test "kmeans++: 质心来自原始数据且不重复" {
  let points = [
    Point::{ coords: [1.0, 2.0], },
    Point::{ coords: [1.5, 1.8], },
    Point::{ coords: [5.0, 8.0], },
    Point::{ coords: [5.5, 7.8], },
    Point::{ coords: [1.0, 0.6], },
    Point::{ coords: [1.3, 0.4], },
  ]
  let centroids = init_centroids_kmeanspp(points, 3)

  // 每个质心都必须是原始数据中的某个点
  for c in 0..<centroids.length() {
    let mut found = false
    for i in 0..<points.length() {
      if centroids[c].coords[0] == points[i].coords[0] &&
        centroids[c].coords[1] == points[i].coords[1] {
        found = true
      }
    }
    assert_eq(found, true)
  }

  // 质心两两不同
  for i in 0..<centroids.length() {
    for j in (i + 1)..<centroids.length() {
      let same = centroids[i].coords[0] == centroids[j].coords[0] &&
        centroids[i].coords[1] == centroids[j].coords[1]
      assert_eq(same, false)
    }
  }
}

///|
pub fn plot_clusters(
  points : Array[Point],
  labels : Array[Int32],
  centroids : Array[Point],
  k : Int32,
) -> String raise {
  let fig = @mathplotlib.figure()

  // 1. 对每个簇，收集属于它的点，用一种颜色画 scatter
  let colors = ["#1f77b4", "#ff7f0e", "#2ca02c", "#d62728", "#9467bd"]
  for c in 0..<k {
    let cluster_points : Array[@mathplotlib.Point] = []
    for i in 0..<points.length() {
      if labels[i] == c {
        cluster_points.push(
          @mathplotlib.point(points[i].coords[0], points[i].coords[1]),
        )
      }
    }
    fig.scatter(
      cluster_points,
      color=colors[c % colors.length()],
      label="簇 \{c}",
    )
  }

  // 2. 把质心也用醒目的标记画上去（可选）
  let centroid_points : Array[@mathplotlib.Point] = []
  for c in 0..<centroids.length() {
    centroid_points.push(
      @mathplotlib.point(centroids[c].coords[0], centroids[c].coords[1]),
    )
  }
  fig.scatter(centroid_points, color="#000000", label="质心")

  // 3. 设置图例并导出 SVG
  fig.set_legend_position(@mathplotlib.LegendPosition::UpperRight)
  fig.to_svg_checked()
}
