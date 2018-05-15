'use strict';

/**
 * Start consent process
 * @param {com.consilx.biznet.SetupConsent} setupConsentData
 * @transaction
 */

function setupConsent(setupConsentData) {
    return getAssetRegistry('com.consilx.biznet.Consent')
        .then(function(assetRegistry) {
            var consent = getFactory().newResource('com.consilx.biznet', 'Consent', setupConsentData.consentId);
            consent.consentId = setupConsentData.consentId;
            consent.status = "NEW";
            consent.patient = setupConsentData.patient;
            consent.consentDocument = setupConsentData.consentDocument;
            return assetRegistry.add(consent);
        });
}

/**
 * Patient provides consent
 * @param {com.consilx.biznet.ProvideConsent} consentData
 * @transaction
 */
function provideConsent(consentData) {
    return getAssetRegistry('com.consilx.biznet.Consent')
        .then(function(assetRegistry) {
                consentData.consent.status = "ACCEPTED";
                return assetRegistry.update(consentData.consent);
        });
}
/**
 * Doctor cosigns consent
 * @param {com.consilx.biznet.CoSignConsent} cosignConsentData
 * @transaction
 */
function coSignConsent(cosignConsentData) {
    return getAssetRegistry('com.consilx.biznet.Consent')
        .then(function(assetRegistry) {
          var doc = getCurrentParticipant()
            cosignConsentData.consent.status = "COSIGNED";
            cosignConsentData.consent.coSignee = doc;
            return assetRegistry.update(cosignConsentData.consent);
        });
}
