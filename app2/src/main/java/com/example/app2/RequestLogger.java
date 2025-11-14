package com.example.app2;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import java.time.Instant;

public class RequestLogger {
    private static final Logger logger = LoggerFactory.getLogger(RequestLogger.class);
    
    public static void logRequestReceived(String requestId, String sourcePod, String sourceHost, 
                                         String destinationPod) {
        logger.info("REQUEST_RECEIVED | requestId={} | sourcePod={} | sourceHost={} | destinationPod={} | timestamp={}", 
            requestId, sourcePod, sourceHost, destinationPod, Instant.now());
    }
    
    public static void logRequestProcessed(String requestId, String sourcePod, String destinationPod, 
                                          long processingTimeMs, long configuredDelayMs) {
        logger.info("REQUEST_PROCESSED | requestId={} | sourcePod={} | destinationPod={} | processingTimeMs={} | configuredDelayMs={} | timestamp={}", 
            requestId, sourcePod, destinationPod, processingTimeMs, configuredDelayMs, Instant.now());
    }
    
    public static void logRequestError(String requestId, String sourcePod, String destinationPod, 
                                      String error) {
        logger.error("REQUEST_ERROR | requestId={} | sourcePod={} | destinationPod={} | error={} | timestamp={}", 
            requestId, sourcePod, destinationPod, error, Instant.now());
    }
}

