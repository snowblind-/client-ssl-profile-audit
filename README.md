# rsa_kx.sh

Reports SSL/TLS key exchange usage for every client-ssl profile on an F5 BIG-IP, and shows how much traffic still uses plain RSA key exchange compared with other methods (ECDHE, DHE, etc.).

Use it to find profiles that still carry RSA key exchange traffic before tightening cipher strings or removing RSA ciphers.

## Requirements

- Run from the **bash** prompt on the BIG-IP, not from inside the tmsh shell.
- An account with permission to run `tmsh show ltm profile client-ssl`.

## Usage

```bash
chmod +x rsa_kx.sh
./rsa_kx.sh [--percent N] [--csv]
```

| Option | Description |
|---|---|
| `--percent N` | Show only profiles whose RSA share is greater than N percent. Also accepts `--percent=N`. |
| `--csv` | Output CSV instead of the text report. Works with `--percent`. |
| `-h`, `--help` | Show usage. |

Without `--percent`, the script lists every profile that has handled at least one handshake.

## Examples

```bash
./rsa_kx.sh                  # all profiles with handshakes
./rsa_kx.sh --percent 10     # profiles where more than 10% of key exchanges are RSA
./rsa_kx.sh --percent=0      # any profile that has seen an RSA key exchange
./rsa_kx.sh --percent 5 --csv > rsa_kx.csv   # CSV of profiles above 5% RSA
```

## Output

```
clientssl
  RSA          1234
  ECDHE-RSA    56789
  RSA:other = 1234:56789  (2.1% RSA)

1 of 12 profiles above 0% RSA

ALL PROFILES
  RSA:other = 1234:61199  (2.0% RSA)
```

For each profile, the output shows:

- The profile name on its own line.
- The RSA count, always shown even when it is 0.
- Any other key exchange method with a count above 0.
- The RSA-to-other ratio and the RSA percentage.

The `ALL PROFILES` line totals every profile on the box, including profiles hidden by `--percent`.

### CSV output

With `--csv`, the script prints one header row and one row per profile:

```
profile,total,rsa,other,rsa_percent,adh,dh-rsa,ecdhe-rsa,rsa,...
clientssl,58023,1234,56789,2.13,0,0,56789,1234,...
```

- The first five columns are fixed: profile, total handshakes, RSA count, other count, and RSA percentage.
- The remaining columns hold one count per key exchange method, including zeros, so every row lines up.
- There is no `ALL PROFILES` row; total the columns in your spreadsheet instead.

## Notes

- Counts come from `tmsh show ltm profile client-ssl field-fmt`, which gives raw integers rather than abbreviated values such as `1.2K`.
- Statistics are cumulative since the last reset or reboot. Run `tmsh reset-stats ltm profile client-ssl` to start a fresh measurement window.
- Profiles exactly at the `--percent` threshold are excluded.
- If profiles show names but no counts, check the field names your version reports:
  ```bash
  tmsh show ltm profile client-ssl field-fmt | grep -i xchg | head
  ```
