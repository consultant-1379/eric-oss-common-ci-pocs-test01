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

package com.ericsson.oss.ci.test.controller.example;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.context.junit.jupiter.SpringExtension;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import org.springframework.web.context.WebApplicationContext;

import com.ericsson.coverage.filter.ContractCoverageFilterV3;
import spock.lang.Specification;

import com.ericsson.oss.ci.test.CoreApplication;

@ExtendWith(SpringExtension.class)
@SpringBootTest(classes = {CoreApplication.class, SampleApiControllerImpl.class})
public class SampleApiControllerTest extends Specification {

    @Autowired
    private WebApplicationContext webApplicationContext;
    private MockMvc mvc;
    @Autowired
    private SampleApiControllerImpl sampleApiController;

    @BeforeEach
    public void setUp() {
        mvc = MockMvcBuilders.webAppContextSetup(webApplicationContext).addFilters(new ContractCoverageFilterV3()).build();
    }

    @Test
    public void sample() throws Exception {
        mvc.perform(get("/v1/sample").contentType(MediaType.APPLICATION_JSON)).andExpect(status().isOk())
                .andExpect(content().string("Sample response"));
    }
}
