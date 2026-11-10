///|
/// Entry point for the CLI or runnable program in this template.
/// Keep main focused; move logic into the library package.
/// Run with `moon run cmd/main` from the project root.

///|
fn main raise {
  // 1. 用 fs 包读取文件内容为字符串
  let content = @fs.read_file_to_string("./iris.csv", encoding="utf8")

  // 2. 用 NyaCSV 解析字符串，得到 CSV 对象
  let csv = @NyaCSV.CSV::parse_string(content)

  // 3. 直接获取二维字符串数组，无需处理表头（Iris 无表头）
  let data = csv.data() 

  // 4. 将字符串转换为 Double，并构造 Point 数组
  let points : Array[@hello_moon.Point] = []

  let normalized_points = @hello_moon.standardize(points)

  // 2. 用标准化后的数据聚类
  for row in data {
    if row.length() >= 4 {
      let coords : Array[Double] = [
        @string.parse_double(row[0]),
        @string.parse_double(row[1]),
        @string.parse_double(row[2]),
        @string.parse_double(row[3]),
      ]
      points.push(@hello_moon.Point::{ coords: coords })
    }
  }

    // 聚类
  let (centroids, labels) = @hello_moon.kmeans(normalized_points, 3, 100, 0.000001)
  println("质心个数: \{centroids.length()}")
  println("每个点的标签: \{labels}")

  // 可视化 + 保存
  let svg = @hello_moon.plot_clusters(normalized_points, labels, centroids)
  let output = "clusters.svg"
  @fs.write_string_to_file(output, svg)
  println("SVG 已写入: \{output}")
}