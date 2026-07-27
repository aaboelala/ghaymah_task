package metrics

import (
	"math"
	"sync"
	"time"
)

// MetricsResponse defines the JSON response structure for the /metrics endpoint.
type MetricsResponse struct {
	Status               string  `json:"status"`
	UptimeSeconds        int64   `json:"uptime_seconds"`
	TotalRequests        uint64  `json:"total_requests"`
	AverageLatencyMS     float64 `json:"average_latency_ms"`
	LastRequestLatencyMS float64 `json:"last_request_latency_ms"`
}

// Tracker maintains thread-safe application metrics.
type Tracker struct {
	mu             sync.RWMutex
	startTime      time.Time
	totalRequests  uint64
	totalLatencyNs int64
	lastLatencyMs  float64
}

// NewTracker initializes and returns a new Tracker instance.
func NewTracker() *Tracker {
	return &Tracker{
		startTime: time.Now(),
	}
}

// RecordRequest safely updates total request count, total latency, and last request latency.
func (t *Tracker) RecordRequest(duration time.Duration) {
	t.mu.Lock()
	defer t.mu.Unlock()

	t.totalRequests++
	t.totalLatencyNs += duration.Nanoseconds()

	// Convert duration to milliseconds as float64 and round to 2 decimal places
	latencyMs := float64(duration.Microseconds()) / 1000.0
	t.lastLatencyMs = math.Round(latencyMs*100) / 100
}

// GetMetrics constructs and returns a snapshot of current metrics.
func (t *Tracker) GetMetrics() MetricsResponse {
	t.mu.RLock()
	defer t.mu.RUnlock()

	uptime := int64(time.Since(t.startTime).Seconds())

	var avgLatency float64
	if t.totalRequests > 0 {
		avgMs := (float64(t.totalLatencyNs) / float64(t.totalRequests)) / 1e6
		avgLatency = math.Round(avgMs*100) / 100
	}

	return MetricsResponse{
		Status:               "healthy",
		UptimeSeconds:        uptime,
		TotalRequests:        t.totalRequests,
		AverageLatencyMS:     avgLatency,
		LastRequestLatencyMS: t.lastLatencyMs,
	}
}
