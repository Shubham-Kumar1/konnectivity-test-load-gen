package com.example.app1;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.HashMap;
import java.util.Map;

@RestController
@RequestMapping("/load")
public class LoadController {

  @Autowired
  private LoadGenerator loadGenerator;

  @PostMapping("/start")
  public ResponseEntity<Map<String, Object>> start() {
    loadGenerator.startLoadGeneration();
    
    Map<String, Object> response = new HashMap<>();
    response.put("status", "started");
    response.put("message", "Load generation started");
    response.put("running", loadGenerator.isLoadGenerationRunning());
    return ResponseEntity.ok(response);
  }

  @PostMapping("/stop")
  public ResponseEntity<Map<String, Object>> stop() {
    loadGenerator.stopLoadGeneration();
    
    Map<String, Object> response = new HashMap<>();
    response.put("status", "stopped");
    response.put("message", "Load generation stopped");
    response.put("running", loadGenerator.isLoadGenerationRunning());
    return ResponseEntity.ok(response);
  }

  @GetMapping("/status")
  public ResponseEntity<Map<String, Object>> status() {
    Map<String, Object> response = new HashMap<>();
    response.put("running", loadGenerator.isLoadGenerationRunning());
    response.put("status", loadGenerator.isLoadGenerationRunning() ? "running" : "stopped");
    return ResponseEntity.ok(response);
  }
}

