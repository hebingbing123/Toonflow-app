/// Parses project video ratio labels (`9:16`, `16:9`, `1:1`) into [AspectRatio] values.
double shortVideoAspectRatioFromLabel(String ratio) {
  switch (ratio.trim()) {
    case '16:9':
      return 16 / 9;
    case '1:1':
      return 1;
    default:
      return 9 / 16;
  }
}
