package duplicates

import (
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"io"
	"os"
	"sort"

	"github.com/Hasninemamud/CleanMac/internal/jsonout"
)

const partialLen = 65536

type Group struct {
	ByteSize         int64          `json:"byteSize"`
	ReclaimableBytes int64          `json:"reclaimableBytes"`
	Files            []jsonout.Item `json:"files"`
}

func partialHash(path string) (string, error) {
	f, err := os.Open(path)
	if err != nil {
		return "", err
	}
	defer f.Close()
	h := sha256.New()
	_, err = io.CopyN(h, f, partialLen)
	if err != nil && err != io.EOF {
		return "", err
	}
	return hex.EncodeToString(h.Sum(nil)), nil
}

func fullHash(path string) (string, error) {
	f, err := os.Open(path)
	if err != nil {
		return "", err
	}
	defer f.Close()
	h := sha256.New()
	if _, err := io.Copy(h, f); err != nil {
		return "", err
	}
	return hex.EncodeToString(h.Sum(nil)), nil
}

func Find(files []jsonout.Item, minimumBytes int64, onProgress func(int, string)) []Group {
	if minimumBytes <= 0 {
		minimumBytes = 1_048_576
	}
	bySize := map[int64][]jsonout.Item{}
	for _, f := range files {
		if f.ByteSize < minimumBytes || f.Safety == "blocked" {
			continue
		}
		bySize[f.ByteSize] = append(bySize[f.ByteSize], f)
	}
	partialBuckets := map[string][]jsonout.Item{}
	visited := 0
	for _, group := range bySize {
		if len(group) < 2 {
			continue
		}
		for _, file := range group {
			visited++
			if visited%20 == 0 && onProgress != nil {
				onProgress(visited, file.Path)
			}
			partial, err := partialHash(file.Path)
			if err != nil {
				continue
			}
			k := fmt.Sprintf("%d-%s", file.ByteSize, partial)
			partialBuckets[k] = append(partialBuckets[k], file)
		}
	}
	var groups []Group
	for _, bucket := range partialBuckets {
		if len(bucket) < 2 {
			continue
		}
		byFull := map[string][]jsonout.Item{}
		for _, file := range bucket {
			visited++
			if onProgress != nil {
				onProgress(visited, file.Path)
			}
			full, err := fullHash(file.Path)
			if err != nil {
				continue
			}
			byFull[full] = append(byFull[full], file)
		}
		for _, matches := range byFull {
			if len(matches) < 2 {
				continue
			}
			bs := matches[0].ByteSize
			groups = append(groups, Group{
				ByteSize: bs, ReclaimableBytes: bs * int64(len(matches)-1), Files: matches,
			})
		}
	}
	sort.Slice(groups, func(i, j int) bool { return groups[i].ReclaimableBytes > groups[j].ReclaimableBytes })
	return groups
}
