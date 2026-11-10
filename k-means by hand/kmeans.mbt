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
pub fn standardize(points : Array[Point]) -> Array[Point] {
  if points.length() == 0 { return points }
  let n = points.length()
  let dim = points[0].dim()
  
  // 1. 计算每一维的均值
  let means = Array::make(dim, 0.0)
  for p in points {
    for d in 0..<dim {
      means[d] = means[d] + p.coords[d]
    }
  }
  for d in 0..<dim {
    means[d] = means[d] / n.to_double()
  }

  // 2. 计算每一维的标准差
  let stds = Array::make(dim, 0.0)
  for p in points {
    for d in 0..<dim {
      let diff = p.coords[d] - means[d]
      stds[d] = stds[d] + diff * diff
    }
  }
  for d in 0..<dim {
    stds[d] = (stds[d] / n.to_double()).sqrt()
    if stds[d] == 0.0 { stds[d] = 1.0 } // 防止除以 0
  }

  // 3. 构造标准化后的新点
  let normalized : Array[Point] = []
  for p in points {
    let coords = Array::make(dim, 0.0)
    for d in 0..<dim {
      coords[d] = (p.coords[d] - means[d]) / stds[d]
    }
    normalized.push(Point::{ coords: coords })
  }
  normalized
}

///|
pub fn plot_clusters(
  points : Array[Point],
  labels : Array[Int],
  centroids : Array[Point],
) -> String raise {
  let fig = @mathplotlib.figure(width=640, height=480)
  fig.set_title("K-means Clustering (Iris, first 2 features)")
  fig.set_x_label("Feature 1")
  fig.set_y_label("Feature 2")

  let colors = ["#1f77b4", "#ff7f0e", "#2ca02c", "#d62728", "#9467bd"]
  let k = centroids.length()

  // 对每个簇，收集 Point 对象，然后用 scatter 画散点
  for c in 0..<k {
    let cluster_points : Array[@mathplotlib.Point] = []
    for i in 0..<points.length() {
  if labels[i] == c {
    cluster_points.push(
      @mathplotlib.point(points[i].coords[0], points[i].coords[1])
    )
  }
}

    if cluster_points.length() > 0 {
      fig.scatter(cluster_points, color=colors[c % colors.length()], label="Cluster \{c}")
    }
  }

  // 质心同样用 scatter 画
  let centroid_points : Array[@mathplotlib.Point] = []
  for c in 0..<k {
  centroid_points.push(
    @mathplotlib.point(centroids[c].coords[0], centroids[c].coords[1])
  )
}
  fig.scatter(centroid_points, color="#000000", label="Centroids")

  fig.legend(fig.legend_entries())
  fig.to_svg_checked()
}