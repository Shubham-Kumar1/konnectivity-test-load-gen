package com.example.app1;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import java.time.Instant;
import java.util.UUID;

public class RequestLogger {
    private static final Logger logger = LoggerFactory.getLogger(RequestLogger.class);
    
    public static String generateRequestId() {
        return UUID.randomUUID().toString().substring(0, 8);
    }
    
    public static void logRequestStart(String requestId, String sourcePod, String targetUrl) {
        logger.info("REQUEST_START | requestId={} | sourcePod={} | targetUrl={} | timestamp={}", 
            requestId, sourcePod, targetUrl, Instant.now());
    }
    
    public static void logRequestSuccess(String requestId, String sourcePod, String targetPod, 
                                        long latencyMs, int statusCode) {
        logger.info("REQUEST_SUCCESS | requestId={} | sourcePod={} | targetPod={} | latencyMs={} | statusCode={} | timestamp={}", 
            requestId, sourcePod, targetPod, latencyMs, statusCode, Instant.now());
    }
    
    public static void logRequestError(String requestId, String sourcePod, String targetUrl, 
                                      long latencyMs, String error) {
        logger.error("REQUEST_ERROR | requestId={} | sourcePod={} | targetUrl={} | latencyMs={} | error={} | timestamp={}", 
            requestId, sourcePod, targetUrl, latencyMs, error, Instant.now());
    }
}

