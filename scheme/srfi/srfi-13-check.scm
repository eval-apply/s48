(define-test-suite srfi-13-tests)

(define-test-case string-contains srfi-13-tests
  (check (string-contains "ab" "ab") => 0)
  (check (string-contains "xabc" "ab") => 1)
  (check (string-contains "aabc" "ab") => 1)
  (check (string-contains "abaabaaabaaaa" "aaa") => 5)
  (check (not (string-contains "abcdef" "cdf"))))

