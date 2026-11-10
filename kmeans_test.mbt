// Blackbox tests run against the package's public API. Use `@hello_moon` to import.
// Prefer high-level behaviors over implementation details.
// Run `moon test` to execute and `moon test --update` to refresh snapshots.
///|
///|
test "squared_distance: 精确整数坐标" {
  let a = @hello_moon.Point::{ coords: [1.0, 2.0] }
  let b = @hello_moon.Point::{ coords: [4.0, 6.0] }
  // (1-4)^2 + (2-6)^2 = 9 + 16 = 25
  assert_eq(squared_distance(a, b), 25.0)
  // 自己到自己距离为 0
  assert_eq(squared_distance(a, a), 0.0)
}

///|
test "assign_labels: 两个分离质心" {
  let points = [
    @hello_moon.Point::{ coords: [1.0, 1.0] },
    @hello_moon.Point::{ coords: [2.0, 2.0] },
    @hello_moon.Point::{ coords: [9.0, 9.0] },
    @hello_moon.Point::{ coords: [8.0, 8.0] },
  ]
  let centroids = [
    @hello_moon.Point::{ coords: [0.0, 0.0] },
    @hello_moon.Point::{ coords: [10.0, 10.0] },
  ]
  let labels = assign_labels(points, centroids)
  assert_eq(labels, [0, 0, 1, 1])
}

///|
test "update_centroids: 均值精确可表示" {
  let points = [
    @hello_moon.Point::{ coords: [1.0, 2.0] },
    @hello_moon.Point::{ coords: [3.0, 4.0] },
    @hello_moon.Point::{ coords: [5.0, 6.0] },
    @hello_moon.Point::{ coords: [10.0, 10.0] },
  ]
  let labels = [0, 0, 0, 1]
  let old_centroids = [
    @hello_moon.Point::{ coords: [0.0, 0.0] },
    @hello_moon.Point::{ coords: [0.0, 0.0] },
  ]
  let new_centroids = update_centroids(points, labels, 2, old_centroids)
  // 簇 0: ((1+3+5)/3, (2+4+6)/3) = (3.0, 4.0)，精确
  assert_eq(new_centroids[0].coords[0], 3.0)
  assert_eq(new_centroids[0].coords[1], 4.0)
  // 簇 1 只有一个点，质心就是它自己
  assert_eq(new_centroids[1].coords[0], 10.0)
  assert_eq(new_centroids[1].coords[1], 10.0)
}

///|
test "update_centroids: 空簇保留旧质心" {
  let points = [
    @hello_moon.Point::{ coords: [1.0, 2.0] },
    @hello_moon.Point::{ coords: [3.0, 4.0] },
  ]
  let labels = [0, 0]
  let old_centroids = [
    @hello_moon.Point::{ coords: [9.0, 9.0] },
    @hello_moon.Point::{ coords: [7.0, 7.0] },
  ]
  let new_centroids = update_centroids(points, labels, 2, old_centroids)
  // 簇 1 是空簇，应原样保留旧质心
  assert_eq(new_centroids[1].coords[0], 7.0)
  assert_eq(new_centroids[1].coords[1], 7.0)
}

///|
test "init_centroids: 数量、维度、来源正确" {
  let points = [
    @hello_moon.Point::{ coords: [1.0, 2.0] },
    @hello_moon.Point::{ coords: [3.0, 4.0] },
    @hello_moon.Point::{ coords: [5.0, 6.0] },
    @hello_moon.Point::{ coords: [7.0, 8.0] },
  ]
  let centroids = init_centroids(points, 3)
  assert_eq(centroids.length(), 3)
  assert_eq(centroids[0].dim(), 2)
  // 每个质心都必须能在 points 中找到
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
  for c1 in 0..<centroids.length() {
    for c2 in (c1 + 1)..<centroids.length() {
      let same = centroids[c1].coords[0] == centroids[c2].coords[0] &&
                 centroids[c1].coords[1] == centroids[c2].coords[1]
      assert_eq(same, false)
    }
  }
}

///|
test "kmeans++: 三个质心分属三个不同的团" {
  let points = [
    // 左上团
    @hello_moon.Point::{ coords: [1.0, 2.0] },
    @hello_moon.Point::{ coords: [1.5, 1.8] },
    @hello_moon.Point::{ coords: [1.2, 1.6] },
    // 右上团
    @hello_moon.Point::{ coords: [5.0, 8.0] },
    @hello_moon.Point::{ coords: [5.5, 7.8] },
    @hello_moon.Point::{ coords: [5.2, 8.2] },
    // 左下团
    @hello_moon.Point::{ coords: [1.0, 0.6] },
    @hello_moon.Point::{ coords: [1.3, 0.4] },
    @hello_moon.Point::{ coords: [0.8, 0.5] },
  ]
  let centroids = init_centroids_kmeanspp(points, 3)
  assert_eq(centroids.length(), 3)

  let group_ids : Array[Int] = []
  for c in 0..<centroids.length() {
    let x = centroids[c].coords[0]
    let y = centroids[c].coords[1]
    let gid = if x > 3.0 {
      1   // 右上
    } else if y > 1.0 {
      0   // 左上
    } else {
      2   // 左下
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
    @hello_moon.Point::{ coords: [1.0, 2.0] },
    @hello_moon.Point::{ coords: [1.5, 1.8] },
    @hello_moon.Point::{ coords: [5.0, 8.0] },
    @hello_moon.Point::{ coords: [5.5, 7.8] },
    @hello_moon.Point::{ coords: [1.0, 0.6] },
    @hello_moon.Point::{ coords: [1.3, 0.4] },
  ]
  let centroids = init_centroids_kmeanspp(points, 3)

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

  for i in 0..<centroids.length() {
    for j in (i + 1)..<centroids.length() {
      let same = centroids[i].coords[0] == centroids[j].coords[0] &&
                 centroids[i].coords[1] == centroids[j].coords[1]
      assert_eq(same, false)
    }
  }
}

///|
test "total_shift_squared: 精确平方和" {
  let old_c = [@hello_moon.Point::{ coords: [0.0, 0.0] }]
  let new_c = [@hello_moon.Point::{ coords: [3.0, 4.0] }]
  // 3^2 + 4^2 = 25
  assert_eq(total_shift_squared(old_c, new_c), 25.0)
}

///|
test "total_shift_squared: 多质心累加" {
  let old_c = [
    @hello_moon.Point::{ coords: [0.0, 0.0] },
    @hello_moon.Point::{ coords: [1.0, 1.0] },
  ]
  let new_c = [
    @hello_moon.Point::{ coords: [3.0, 4.0] },
    @hello_moon.Point::{ coords: [1.0, 1.0] },
  ]
  assert_eq(total_shift_squared(old_c, new_c), 25.0)
}

///|
test "standardize: 基础测试" {
  // 数据: [1.0], [3.0], [5.0]
  // 均值: 3.0, 标准差: sqrt(((1-3)^2+(3-3)^2+(5-3)^2)/3) = sqrt(8/3) ≈ 1.63299
  let points = [
    @hello_moon.Point::{ coords: [1.0, 10.0] },
    @hello_moon.Point::{ coords: [3.0, 20.0] },
    @hello_moon.Point::{ coords: [5.0, 30.0] },
  ]
  let normalized = standardize(points)
  
  // 检查第 0 维 (均值 3.0)
  assert_eq(normalized[0].coords[0] < 0.0, true)
  assert_eq(normalized[1].coords[0] == 0.0, true)  // 中间值标准化后为 0
  assert_eq(normalized[2].coords[0] > 0.0, true)
  
  // 检查第 1 维 (均值 20.0)
  assert_eq(normalized[0].coords[1] < 0.0, true)
  assert_eq(normalized[1].coords[1] == 0.0, true)
  assert_eq(normalized[2].coords[1] > 0.0, true)
}

///|
test "kmeans: 三团点稳定分开" {
  let points = [
    // 左上团
    @hello_moon.Point::{ coords: [1.0, 2.0] },
    @hello_moon.Point::{ coords: [1.5, 1.8] },
    @hello_moon.Point::{ coords: [1.2, 1.6] },
    // 右上团
    @hello_moon.Point::{ coords: [5.0, 8.0] },
    @hello_moon.Point::{ coords: [5.5, 7.8] },
    @hello_moon.Point::{ coords: [5.2, 8.2] },
    // 左下团
    @hello_moon.Point::{ coords: [1.0, 0.6] },
    @hello_moon.Point::{ coords: [1.3, 0.4] },
    @hello_moon.Point::{ coords: [0.8, 0.5] },
  ]
  let (centroids, labels) = kmeans(points, 3, 100, 0.000001)
  assert_eq(centroids.length(), 3)
  
  // 同团内标签一致
  assert_eq(labels[0], labels[1])
  assert_eq(labels[1], labels[2])
  assert_eq(labels[3], labels[4])
  assert_eq(labels[4], labels[5])
  assert_eq(labels[6], labels[7])
  assert_eq(labels[7], labels[8])
  
  // 三团标签两两不同
  assert_eq(labels[0] == labels[3], false)
  assert_eq(labels[0] == labels[6], false)
  assert_eq(labels[3] == labels[6], false)
}