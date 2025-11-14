package com.example.app1;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.context.event.ApplicationReadyEvent;
import org.springframework.context.event.EventListener;
import org.springframework.http.*;
import org.springframework.http.client.SimpleClientHttpRequestFactory;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestTemplate;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.time.Instant;
import java.util.*;
import java.util.concurrent.*;

@Component
public class LoadGenerator {

  private static final Logger logger = LoggerFactory.getLogger(LoadGenerator.class);

  @Value("${SERVICE_NAME:app1}")
  private String serviceName;

  @Value("${TARGET_URL:http://app2-service:8080}")
  private String targetUrl;

  @Value("${LOAD_RPS:100}")
  private int rps;

  @Value("${THREAD_POOL_SIZE:50}")
  private int threadPoolSize;

  @Value("${KEEP_ALIVE:true}")
  private boolean keepAlive;

  @Value("${POD_NAME:unknown}")
  private String podName;

  @Value("${HOSTNAME:unknown}")
  private String hostname;

  private RestTemplate rest;
  private ExecutorService pool;

  @EventListener(ApplicationReadyEvent.class)
  public void startLoad() {
    this.rest = createRestTemplate();
    this.pool = Executors.newFixedThreadPool(threadPoolSize);

    logger.info("=== Load Generator Started ===");
    logger.info("Service: {}, Pod: {}, Host: {}", serviceName, podName, hostname);
    logger.info("Target: {}, RPS: {}, Threads: {}, KeepAlive: {}", targetUrl, rps, threadPoolSize, keepAlive);
    logger.info("==============================");

    ScheduledExecutorService scheduler = Executors.newScheduledThreadPool(1);
    int perTick = Math.max(1, rps / 5);

    scheduler.scheduleAtFixedRate(() -> {
      for (int i = 0; i < perTick; i++) {
        pool.submit(this::sendPost);
      }
    }, 0, 200, TimeUnit.MILLISECONDS);
  }

  private RestTemplate createRestTemplate() {
    if (keepAlive) {
      logger.info("Using Keep-Alive");
      return new RestTemplate();
    } else {
      logger.info("Disabling Keep-Alive");
      SimpleClientHttpRequestFactory factory = new SimpleClientHttpRequestFactory() {
        @Override
        protected void prepareConnection(java.net.HttpURLConnection conn, String method)
            throws java.io.IOException {
          super.prepareConnection(conn, method);
          conn.setRequestProperty("Connection", "close");
        }
      };
      return new RestTemplate(factory);
    }
  }

  private void sendPost() {
    String requestId = RequestLogger.generateRequestId();
    long startTime = System.nanoTime();
    
    try {
      String url = targetUrl + "/post";
      Map<String, Object> payload = new HashMap<>();
      payload.put("ts", Instant.now().toString());
      payload.put("sourceService", serviceName);
      payload.put("sourcePod", podName);
      payload.put("sourceHostname", hostname);
      payload.put("requestId", requestId);

      HttpHeaders headers = new HttpHeaders();
      headers.setContentType(MediaType.APPLICATION_JSON);
      headers.add("X-App1-Pod", podName);
      headers.add("X-App1-Hostname", hostname);
      headers.add("X-Request-Id", requestId);

      HttpEntity<Map<String, Object>> entity = new HttpEntity<>(payload, headers);

      // Log request start
      RequestLogger.logRequestStart(requestId, podName, url);

      long requestStart = System.nanoTime();
      ResponseEntity<String> resp = rest.postForEntity(url, entity, String.class);
      long requestLatencyMs = (System.nanoTime() - requestStart) / 1_000_000;
      
      // Extract target pod from response if available
      String targetPod = "unknown";
      try {
        // Response might contain target pod info, but we'll log what we know
        targetPod = extractTargetPodFromResponse(resp.getBody());
      } catch (Exception e) {
        // Ignore parsing errors
      }

      long totalLatencyMs = (System.nanoTime() - startTime) / 1_000_000;
      
      // Log successful request with full details
      RequestLogger.logRequestSuccess(requestId, podName, targetPod, totalLatencyMs, resp.getStatusCode().value());
      
      // Additional detailed log
      logger.debug("Request details | requestId={} | from={} | to={} | httpLatency={}ms | totalLatency={}ms | status={}", 
          requestId, podName, targetPod, requestLatencyMs, totalLatencyMs, resp.getStatusCode());
          
    } catch (Exception ex) {
      long totalLatencyMs = (System.nanoTime() - startTime) / 1_000_000;
      RequestLogger.logRequestError(requestId, podName, targetUrl, totalLatencyMs, ex.getMessage());
      logger.error("Request failed | requestId={} | from={} | error={} | latency={}ms", 
          requestId, podName, ex.getMessage(), totalLatencyMs, ex);
    }
  }
  
  private String extractTargetPodFromResponse(String responseBody) {
    if (responseBody == null) return "unknown";
    try {
      // Try to extract toApp2Pod from JSON response
      if (responseBody.contains("\"toApp2Pod\"")) {
        int start = responseBody.indexOf("\"toApp2Pod\"") + 13;
        int end = responseBody.indexOf("\"", start);
        if (end > start) {
          return responseBody.substring(start, end);
        }
      }
    } catch (Exception e) {
      // Ignore parsing errors
    }
    return "unknown";
  }
}
