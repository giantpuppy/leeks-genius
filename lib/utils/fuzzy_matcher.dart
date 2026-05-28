/// 中文优化的模糊匹配引擎
/// 基于 Levenshtein 距离，支持中文文本

class FuzzyMatcher {
  /// 计算两个字符串的 Levenshtein 编辑距离
  static int levenshtein(String s1, String s2) {
    if (s1.isEmpty) return s2.length;
    if (s2.isEmpty) return s1.length;

    final m = s1.length;
    final n = s2.length;

    // 使用两行滚动数组优化空间
    var prev = List<int>.generate(n + 1, (i) => i);
    var curr = List<int>.filled(n + 1, 0);

    for (var i = 1; i <= m; i++) {
      curr[0] = i;
      for (var j = 1; j <= n; j++) {
        final cost = s1[i - 1] == s2[j - 1] ? 0 : 1;
        curr[j] = _min3(
          prev[j] + 1,      // 删除
          curr[j - 1] + 1,  // 插入
          prev[j - 1] + cost, // 替换
        );
      }
      final temp = prev;
      prev = curr;
      curr = temp;
    }

    return prev[n];
  }

  static int _min3(int a, int b, int c) {
    var min = a;
    if (b < min) min = b;
    if (c < min) min = c;
    return min;
  }

  /// 计算相似度 [0.0, 1.0]，1.0 表示完全相同
  static double similarity(String s1, String s2) {
    if (s1.isEmpty && s2.isEmpty) return 1.0;
    if (s1.isEmpty || s2.isEmpty) return 0.0;
    if (s1 == s2) return 1.0;

    final dist = levenshtein(s1, s2);
    final maxLen = s1.length > s2.length ? s1.length : s2.length;

    // 基础相似度
    var score = 1.0 - dist / maxLen;

    // 前缀匹配 bonus：共享前缀越长，bonus 越大
    final prefixLen = _commonPrefixLength(s1, s2);
    if (prefixLen >= 2) {
      score += 0.05 * (prefixLen / maxLen);
    }

    // 后缀匹配 bonus
    final suffixLen = _commonSuffixLength(s1, s2);
    if (suffixLen >= 2) {
      score += 0.03 * (suffixLen / maxLen);
    }

    // 长度差异惩罚：长度差异越大，相似度越低
    final lenDiff = (s1.length - s2.length).abs();
    if (lenDiff > 3) {
      score -= 0.05 * lenDiff;
    }

    return score.clamp(0.0, 1.0);
  }

  static int _commonPrefixLength(String s1, String s2) {
    final minLen = s1.length < s2.length ? s1.length : s2.length;
    var count = 0;
    for (var i = 0; i < minLen; i++) {
      if (s1[i] == s2[i]) {
        count++;
      } else {
        break;
      }
    }
    return count;
  }

  static int _commonSuffixLength(String s1, String s2) {
    final minLen = s1.length < s2.length ? s1.length : s2.length;
    var count = 0;
    for (var i = 1; i <= minLen; i++) {
      if (s1[s1.length - i] == s2[s2.length - i]) {
        count++;
      } else {
        break;
      }
    }
    return count;
  }

  /// 在候选列表中找最佳匹配
  /// 返回匹配项和相似度，如果最高相似度低于 threshold 则返回 null
  static ({String? match, double score}) findBestMatch(
    String input,
    List<String> candidates, {
    double threshold = 0.5,
  }) {
    if (input.isEmpty || candidates.isEmpty) {
      return (match: null, score: 0.0);
    }

    String? bestMatch;
    var bestScore = 0.0;

    for (final candidate in candidates) {
      final score = similarity(input, candidate);
      if (score > bestScore) {
        bestScore = score;
        bestMatch = candidate;
      }
    }

    if (bestScore >= threshold) {
      return (match: bestMatch, score: bestScore);
    }
    return (match: null, score: bestScore);
  }

  /// 批量匹配：对输入列表中的每一项，在候选列表中找最佳匹配
  /// 返回 Map<原始文本, (匹配项, 相似度)>
  static Map<String, ({String? match, double score})> batchMatch(
    List<String> inputs,
    List<String> candidates, {
    double threshold = 0.5,
  }) {
    final results = <String, ({String? match, double score})>{};
    for (final input in inputs) {
      results[input] = findBestMatch(input, candidates, threshold: threshold);
    }
    return results;
  }
}
