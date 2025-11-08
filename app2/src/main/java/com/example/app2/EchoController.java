package com.example.app2;

import jakarta.servlet.http.HttpServletRequest;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import java.time.Instant;
import java.util.*;

@RestController
public class EchoController {

  @PostMapping("/post")
  public ResponseEntity<Map<String, Object>> post(@RequestBody(required = false) Map<String, Object> body,
                                                  HttpServletRequest req) {
    String app1Pod = req.getHeader("X-App1-Pod");
    String app1Host = req.getHeader("X-App1-Hostname");
    String app2Pod = System.getenv().getOrDefault("POD_NAME", "unknown");

    Map<String, Object> resp = new HashMap<>();
    resp.put("ack", "ok");
    resp.put("fromApp1Pod", app1Pod);
    resp.put("fromApp1Host", app1Host);
    resp.put("toApp2Pod", app2Pod);
    resp.put("ts", Instant.now().toString());

    System.out.printf("[%s] app2Pod=%s <- from %s (%s)%n",
        Instant.now(), app2Pod, app1Pod, app1Host);

    return ResponseEntity.ok(resp);
  }

  @GetMapping("/ping")
  public String ping() {
    return "pong";
  }
}
