package com.example.app2;

import jakarta.servlet.http.HttpServletRequest;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import java.time.Instant;
import java.util.*;

@RestController
public class EchoController {

  private static final Logger logger = LoggerFactory.getLogger(EchoController.class);

  @Value("${RESPONSE_DELAY_MS:50}")
  private long responseDelayMs;

  @PostMapping("/post")
  public ResponseEntity<Map<String, Object>> post(@RequestBody(required = false) Map<String, Object> body,
                                                  HttpServletRequest req) {
    long startTime = System.nanoTime();
    String requestId = req.getHeader("X-Request-Id");
    if (requestId == null || requestId.isEmpty()) {
      requestId = "unknown-" + System.currentTimeMillis();
    }
    
    String app1Pod = req.getHeader("X-App1-Pod");
    String app1Host = req.getHeader("X-App1-Hostname");
    String app2Pod = System.getenv().getOrDefault("POD_NAME", "unknown");
    String app2Host = System.getenv().getOrDefault("HOSTNAME", "unknown");

    // Log request received
    RequestLogger.logRequestReceived(requestId, 
        app1Pod != null ? app1Pod : "unknown",
        app1Host != null ? app1Host : "unknown",
        app2Pod);

    // Introduce configurable delay
    long delayStart = System.nanoTime();
    try {
      Thread.sleep(responseDelayMs);
    } catch (InterruptedException e) {
      Thread.currentThread().interrupt(); // restore interrupt flag
    }
    long actualDelayMs = (System.nanoTime() - delayStart) / 1_000_000;

    Map<String, Object> resp = new HashMap<>();
    resp.put("ack", "ok");
    resp.put("requestId", requestId);
    resp.put("fromApp1Pod", app1Pod);
    resp.put("fromApp1Host", app1Host);
    resp.put("toApp2Pod", app2Pod);
    resp.put("toApp2Host", app2Host);
    resp.put("ts", Instant.now().toString());
    resp.put("processingTimeMs", (System.nanoTime() - startTime) / 1_000_000);

    long totalProcessingTimeMs = (System.nanoTime() - startTime) / 1_000_000;
    
    // Log request processed with full details
    RequestLogger.logRequestProcessed(requestId, 
        app1Pod != null ? app1Pod : "unknown",
        app2Pod,
        totalProcessingTimeMs,
        responseDelayMs);
    
    // Additional detailed log
    logger.debug("Request processing details | requestId={} | from={} | to={} | processingTime={}ms | configuredDelay={}ms | actualDelay={}ms", 
        requestId, app1Pod, app2Pod, totalProcessingTimeMs, responseDelayMs, actualDelayMs);

    return ResponseEntity.ok(resp);
  }

  @GetMapping("/ping")
  public String ping() {
    return "pong";
  }

  @GetMapping("/health")
  public ResponseEntity<Map<String, Object>> health() {
    String app2Pod = System.getenv().getOrDefault("POD_NAME", "unknown");
    String hostname = System.getenv().getOrDefault("HOSTNAME", "unknown");
    
    Map<String, Object> health = new HashMap<>();
    health.put("status", "UP");
    health.put("service", "app2");
    health.put("pod", app2Pod);
    health.put("hostname", hostname);
    health.put("timestamp", Instant.now().toString());
    health.put("responseDelayMs", responseDelayMs);
    
    logger.debug("Health check requested");
    return ResponseEntity.ok(health);
  }
}
