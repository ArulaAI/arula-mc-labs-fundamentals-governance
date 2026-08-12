package com.mc.auth.service;

/**
 * PAN utilities.
 */
public final class PanTools {

    private PanTools() {
    }

    /** Returns the last 4 digits only, e.g. {@code **** **** **** 1111}. */
    public static String mask(String pan) {
        if (pan == null || pan.length() < 4) {
            return "****";
        }
        String last4 = pan.substring(pan.length() - 4);
        return "**** **** **** " + last4;
    }

    /**
     * Luhn checksum validation.
     */
    public static boolean isLuhnValid(String pan) {
        if (pan == null || pan.isBlank()) {
            return false;
        }
        int sum = 0;
        boolean alternate = false;
        for (int i = pan.length() - 1; i >= 0; i--) {
            char c = pan.charAt(i);
            if (!Character.isDigit(c)) {
                return false;
            }
            int digit = c - '0';
            if (alternate) {
                digit *= 2;
                if (digit > 9) {
                    digit -= 9;
                }
            }
            sum += digit;
            alternate = !alternate;
        }
        return sum % 10 == 0;
    }
}
