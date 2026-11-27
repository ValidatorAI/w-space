# Least Vulnerable Variant

## Winner
`hermes:ultra-hardened` is the least vulnerable image in the reviewed scan set.

## Evidence

| Image | Total vulnerabilities | CRITICAL | HIGH | MEDIUM | LOW | UNKNOWN |
|---|---:|---:|---:|---:|---:|---:|
| hermes:ultra-hardened | 628 | 1 | 101 | 260 | 225 | 41 |
| hermes:slim | 1828 | 1 | 151 | 657 | 963 | 56 |
| hermes:hardened | 1862 | 2 | 158 | 668 | 978 | 56 |
| nousresearch/hermes-agent:stable-desktop | 3954 | 3 | 758 | 1574 | 1349 | 270 |
| nousresearch/hermes-agent:latest-desktop | 3954 | 3 | 758 | 1574 | 1349 | 270 |

## High + Medium comparison

| Image | HIGH | MEDIUM | HIGH + MEDIUM |
|---|---:|---:|---:|
| hermes:ultra-hardened | 101 | 260 | 361 |
| hermes:slim | 151 | 657 | 808 |
| hermes:hardened | 158 | 668 | 826 |
| stable/latest desktop | 758 | 1574 | 2332 |

## Conclusion
The ultra-hardened build is clearly the least risky option. It has the lowest total vulnerability count and the lowest HIGH + MEDIUM exposure. The differences are mainly driven by the Debian base image layer, while the dependency totals remain largely consistent across all variants.
