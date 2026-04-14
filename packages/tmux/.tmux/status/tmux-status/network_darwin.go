package main

/*
#include <sys/types.h>
#include <sys/socket.h>
#include <ifaddrs.h>
#include <net/if.h>
#include <net/if_dl.h>
#include <string.h>

struct net_bytes {
    unsigned long long rx;
    unsigned long long tx;
};

struct net_bytes get_net_bytes() {
    struct net_bytes result = {0, 0};
    struct ifaddrs *ifap, *ifa;

    if (getifaddrs(&ifap) != 0) return result;

    for (ifa = ifap; ifa != NULL; ifa = ifa->ifa_next) {
        if (ifa->ifa_addr == NULL) continue;
        if (ifa->ifa_addr->sa_family != AF_LINK) continue;
        if (strncmp(ifa->ifa_name, "lo", 2) == 0) continue;

        struct if_data *ifd = (struct if_data *)ifa->ifa_data;
        if (ifd == NULL) continue;

        result.rx += ifd->ifi_ibytes;
        result.tx += ifd->ifi_obytes;
    }

    freeifaddrs(ifap);
    return result;
}
*/
import "C"

import (
	"fmt"
	"os"
	"strconv"
	"strings"
	"time"
)

const netWindow = 5 * time.Second

func collectNetwork() string {
	bytes := C.get_net_bytes()
	rxBytes := int64(bytes.rx)
	txBytes := int64(bytes.tx)
	nowMs := time.Now().UnixMilli()

	cache := cachePath("net")
	var rxRate, txRate int64

	data, err := os.ReadFile(cache)
	if err == nil {
		parts := strings.Fields(string(data))
		if len(parts) == 3 {
			prevMs, _ := strconv.ParseInt(parts[0], 10, 64)
			prevRx, _ := strconv.ParseInt(parts[1], 10, 64)
			prevTx, _ := strconv.ParseInt(parts[2], 10, 64)
			elapsedMs := nowMs - prevMs
			if elapsedMs > 0 {
				rxRate = (rxBytes - prevRx) * 1000 / elapsedMs
				txRate = (txBytes - prevTx) * 1000 / elapsedMs
			}
			if elapsedMs >= netWindow.Milliseconds() {
				os.WriteFile(cache, []byte(fmt.Sprintf("%d %d %d", nowMs, rxBytes, txBytes)), 0644)
			}
			return fmt.Sprintf("↑%s ↓%s", formatRate(txRate), formatRate(rxRate))
		}
	}

	os.WriteFile(cache, []byte(fmt.Sprintf("%d %d %d", nowMs, rxBytes, txBytes)), 0644)
	return fmt.Sprintf("↑%s ↓%s", formatRate(txRate), formatRate(rxRate))
}
