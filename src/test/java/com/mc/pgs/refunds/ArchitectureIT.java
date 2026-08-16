package com.mc.pgs.refunds;

import com.tngtech.archunit.core.importer.ClassFileImporter;
import com.tngtech.archunit.lang.ArchRule;
import org.junit.jupiter.api.Test;

import static com.tngtech.archunit.lang.syntax.ArchRuleDefinition.noClasses;

/**
 * F8 (RISK_REGISTER.md): the controller layer must not reach into the repository layer
 * directly -- persistence access and privilege evaluation belong in RefundService. This
 * runs during `mvn verify` (failsafe, not surefire -- see the *IT naming convention and the
 * failsafe binding in pom.xml), so `mvn test` stays green on a fresh clone while `mvn verify`
 * fails until RefundController stops depending on RefundRecordDao directly.
 */
class ArchitectureIT {

    @Test
    void controllersMustNotAccessTheRepositoryLayerDirectly() {
        ArchRule rule = noClasses()
                .that().resideInAPackage("..api..")
                .should().dependOnClassesThat().resideInAPackage("..repo..")
                .because("privilege evaluation and persistence access belong in the service layer, "
                        + "not the controller (F8) -- the controller should only call RefundService");

        rule.check(new ClassFileImporter().importPackages("com.mc.pgs.refunds"));
    }
}
