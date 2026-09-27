package format

import "fmt"

func Bytes(n int64) string {
	return formatBytes(n, 1024)
}

// DiskBytes uses decimal (1000) units to match macOS System Settings Storage.
func DiskBytes(n int64) string {
	return formatBytes(n, 1000)
}

func formatBytes(n int64, base float64) string {
	if n < int64(base) {
		return fmt.Sprintf("%d B", n)
	}
	units := []string{"KB", "MB", "GB", "TB"}
	v := float64(n) / base
	i := 0
	for v >= base && i < len(units)-1 {
		v /= base
		i++
	}
	if v >= 10 || i == 0 {
		return fmt.Sprintf("%.0f %s", v, units[i])
	}
	return fmt.Sprintf("%.1f %s", v, units[i])
}
