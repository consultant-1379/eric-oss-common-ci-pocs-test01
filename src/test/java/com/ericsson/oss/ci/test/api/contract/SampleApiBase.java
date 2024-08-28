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

package com.ericsson.oss.ci.test.api.contract;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import org.springframework.test.web.servlet.setup.StandaloneMockMvcBuilder;

import com.ericsson.oss.ci.test.controller.example.SampleApiControllerImpl;

import io.restassured.module.mockmvc.RestAssuredMockMvc;

@ExtendWith(MockitoExtension.class)
public class SampleApiBase {
    @InjectMocks
    private SampleApiControllerImpl sampleApiController;

    @BeforeEach
    public void setup() {
        final StandaloneMockMvcBuilder standaloneMockMvcBuilder = MockMvcBuilders.standaloneSetup(sampleApiController);
        RestAssuredMockMvc.standaloneSetup(standaloneMockMvcBuilder);
    }
}
