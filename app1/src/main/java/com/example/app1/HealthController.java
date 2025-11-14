package com.example.app1;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

import java.time.Instant;
import java.util.HashMap;
import java.util.Map;

@RestController
public class HealthController {

  @Value("${SERVICE_NAME:app1}")
  private String serviceName;

  @GetMapping("/health")
  public ResponseEntity<Map<String, Object>> health() {
    String podName = System.getenv().getOrDefault("POD_NAME", "unknown");
    String hostname = System.getenv().getOrDefault("HOSTNAME", "unknown");
    
    Map<String, Object> health = new HashMap<>();
    health.put("status", "UP");
    health.put("service", serviceName);
    health.put("pod", podName);
    health.put("hostname", hostname);
    health.put("timestamp", Instant.now().toString());
    return ResponseEntity.ok(health);
  }

  @GetMapping("/ping")
  public String ping() {
    return "pong";
  }
}

