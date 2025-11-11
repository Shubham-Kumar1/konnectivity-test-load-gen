kubectl logs -l app=app1 | \
awk '{
  if ($0 ~ /-> *[0-9]{3}/) {
    match($0, /-> *([0-9]{3})/, m);
    code = m[1];
  } else {
    code = "NO_CODE";
  }
  counts[code]++;
}
END {
  for (c in counts) {
    printf "%s %d\n", c, counts[c];
  }
}' | sort -k2 -nr

