package com.example.app1;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.context.event.ApplicationReadyEvent;
import org.springframework.context.event.EventListener;
import org.springframework.http.*;
import org.springframework.http.client.SimpleClientHttpRequestFactory;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestTemplate;

import java.time.Instant;
import java.util.*;
import java.util.concurrent.*;

@Component
public class LoadGenerator {

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

    System.out.println("=== Load Generator Started ===");
    System.out.printf("Service: %s, Pod: %s, Host: %s%n", serviceName, podName, hostname);
    System.out.printf("Target: %s, RPS: %d, Threads: %d, KeepAlive: %b%n",
        targetUrl, rps, threadPoolSize, keepAlive);
    System.out.println("==============================");

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
      System.out.println("Using Keep-Alive");
      return new RestTemplate();
    } else {
      System.out.println("Disabling Keep-Alive");
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
    try {
      String url = targetUrl + "/post";
      Map<String, Object> payload = new HashMap<>();
      payload.put("ts", Instant.now().toString());
      payload.put("sourceService", serviceName);
      payload.put("sourcePod", podName);
      payload.put("sourceHostname", hostname);

      HttpHeaders headers = new HttpHeaders();
      headers.setContentType(MediaType.APPLICATION_JSON);
      headers.add("X-App1-Pod", podName);
      headers.add("X-App1-Hostname", hostname);

      HttpEntity<Map<String, Object>> entity = new HttpEntity<>(payload, headers);

      long start = System.nanoTime();
      ResponseEntity<String> resp = rest.postForEntity(url, entity, String.class);
      long elapsedMs = (System.nanoTime() - start) / 1_000_000;

      System.out.printf("[%s] Sent POST -> %s (%d ms)%n", Instant.now(), resp.getStatusCode(), elapsedMs);
    } catch (Exception ex) {
      System.err.println("Error: " + ex.getMessage());
    }
  }
}
