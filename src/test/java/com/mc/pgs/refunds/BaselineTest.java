package com.mc.pgs.refunds;

import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * One passing test -- confirms the application context loads on a fresh clone. Do not add
 * findings-related assertions here; Stage 3 writes the red-proof tests for F1/F2 separately.
 */
@SpringBootTest
class BaselineTest {

    @Test
    void contextLoads() {
        assertThat(true).isTrue();
    }
}
