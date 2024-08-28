/*******************************************************************************
 * COPYRIGHT Ericsson 2021
 *
 *
 *
 * The copyright to the computer program(s) herein is the property of
 *
 * Ericsson Inc. The programs may be used and/or copied only with written
 *
 * permission from Ericsson Inc. or in accordance with the terms and
 *
 * conditions stipulated in the agreement/contract under which the
 *
 * program(s) have been supplied.
 ******************************************************************************/

package com.ericsson.oss.ci.test.controller.health;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.actuate.health.Health;
import org.springframework.boot.actuate.health.HealthIndicator;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.stereotype.Component;

/**
 * Health Check component for microservice chassis.
 * Any internal logic can change health state of the chassis.
 */

@ConfigurationProperties(prefix = "info.app")
@Component
public final class HealthCheck implements HealthIndicator {

    /**
     * Logger for the class.
     */
    private static final Logger LOG =
            LoggerFactory.getLogger(HealthCheck.class);

    /**
     * Error upon health check.
     */
    private String errorMessage;

    /**
     * Name of the service.
     */
    private String name;

    @Override
    public Health health() {
        LOG.trace("Invoking chassis specific health check");
        final String errorCode = getErrorMessage();
        if (errorCode != null) {
            return Health.down().withDetail("Error: ", errorCode).build();
        }
        LOG.info("{} is UP and healthy", this.name);
        return Health.up().build();
    }

    /**
     * Set the error message that will cause fail health check of micro service.
     *
     * @param errorMessage Error message from health check.
     */
    public void failHealthCheck(final String errorMessage) {
        this.errorMessage = errorMessage;
    }

    /**
     * Getter method for error message.
     *
     * @return errorMessage status of the service
     */
    private String getErrorMessage() {
        return this.errorMessage;
    }

    /**
     * Setter method for service name.
     */
    public void setName(String name) {
        this.name = name;
    }
}
