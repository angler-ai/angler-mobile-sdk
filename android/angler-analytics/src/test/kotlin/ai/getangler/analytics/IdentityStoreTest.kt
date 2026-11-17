package ai.getangler.analytics

import ai.getangler.analytics.storage.IdentityStore
import ai.getangler.analytics.storage.InMemoryStore
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class IdentityStoreTest {
    @Test fun aidCreatedOnceAndPersisted() {
        val s = InMemoryStore()
        val (aid1, new1) = IdentityStore(s).ensureAid()
        val (aid2, new2) = IdentityStore(s).ensureAid()
        assertTrue(new1)
        assertFalse(new2)
        assertEquals(aid1, aid2)
        assertEquals(aid1.lowercase(), aid1)
    }

    @Test fun reservedIdentifierRejected() {
        val ids = IdentityStore(InMemoryStore())
        for (n in listOf("aid", "customer_id", "idfa", "gaid", "gclid", "sccid", "epik", "")) {
            assertFalse(n, ids.setIdentifier(n, "x"))
        }
        assertTrue(ids.customIdentifiers.isEmpty())
    }

    @Test fun customIdentifierSetAndRemoved() {
        val s = InMemoryStore()
        assertTrue(IdentityStore(s).setIdentifier("appsflyer_id", "af-1"))
        assertEquals(mapOf("appsflyer_id" to "af-1"), IdentityStore(s).customIdentifiers)
        assertTrue(IdentityStore(s).setIdentifier("appsflyer_id", null))
        assertTrue(IdentityStore(s).customIdentifiers.isEmpty())
    }

    @Test fun flagsDefaultTrueAndPersist() {
        val s = InMemoryStore()
        val ids = IdentityStore(s)
        assertTrue(ids.isEnabled)
        assertTrue(ids.applicationTrackingEnabled)
        ids.isEnabled = false
        ids.applicationTrackingEnabled = false
        assertFalse(IdentityStore(s).isEnabled)
        assertFalse(IdentityStore(s).applicationTrackingEnabled)
    }

    @Test fun resetRotatesAidAndClearsUser() {
        val s = InMemoryStore()
        val ids = IdentityStore(s)
        val aid = ids.ensureAid().first
        ids.customerId = "cust-1"
        ids.setIdentifier("appsflyer_id", "af-1")
        ids.reset()
        assertNull(ids.customerId)
        assertTrue(ids.customIdentifiers.isEmpty())
        val (after, isNew) = IdentityStore(s).ensureAid()
        assertFalse(isNew)
        assertNotEquals(aid, after)
    }

    @Test fun resetBeforeAnyAidLeavesFirstLaunchAnInstall() {
        val s = InMemoryStore()
        IdentityStore(s).reset()
        assertTrue(IdentityStore(s).ensureAid().second)
    }
}
