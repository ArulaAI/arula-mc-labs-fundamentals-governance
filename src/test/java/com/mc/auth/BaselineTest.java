package com.mc.auth;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

/**
 * Green baseline: the context loads, and a benign authorization returns a
 * decision. Deliberately does NOT assert on secure behavior — that's what
 * the Stage 3 security tests are for (and why they're red before
 * remediation). This test should never turn red as a side effect of fixing
 * V1/V2/V3.
 */
@SpringBootTest
@AutoConfigureMockMvc
class BaselineTest {

    @Autowired
    private MockMvc mockMvc;

    @Test
    void contextLoads() {
    }

    @Test
    void benignAuthorizationReturnsADecision() throws Exception {
        String body = """
                {
                  "pan": "4111111111111111",
                  "cvv": "123",
                  "expiry": "12/29",
                  "amountMinor": 5000,
                  "currency": "USD",
                  "merchantId": "merchant-1",
                  "idempotencyKey": null
                }
                """;

        mockMvc.perform(post("/authorizations")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(body))
                .andExpect(status().isOk());
    }
}
