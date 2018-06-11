
'use strict';
const shim = require('fabric-shim');
const util = require('util');

let Chaincode = class {
  async Init(stub) {
    let ret = stub.getFunctionAndParameters();
    console.info(ret);
    console.info('=========== Instantiated Consent Chaincode ===========');
    return shim.success();
  }

  async Invoke(stub) {
    console.info('Transaction ID: ' + stub.getTxID());
    console.info(util.format('Args: %j', stub.getArgs()));

    let ret = stub.getFunctionAndParameters();
    console.info(ret);

    let method = this[ret.fcn];
    if (!method) {
      console.log('no function of name:' + ret.fcn + ' found');
      throw new Error('Received unknown function ' + ret.fcn + ' invocation');
    }
    try {
      let payload = await method(stub, ret.params, this);
      return shim.success(payload);
    } catch (err) {
      console.log(err);
      return shim.error(err);
    }
  }

  // ===============================================
  // initParticipant - Onboard participant
  // ===============================================
  async initParticipant(stub, args, thisClass) {
    if (args.length != 2) {
      throw new Error('Incorrect number of arguments. Expecting 2');
    }
    // ==== Input sanitation ====
    console.info('--- start init participant ---')
    if (args[0].length <= 0) {
      throw new Error('1st argument must be a non-empty string');
    }
    if (args[1].length <= 0) {
      throw new Error('2nd argument must be a non-empty string');
    }

    let participantEmailId = args[0].toLowerCase();
    let participantName = args[1].toLowerCase();

    // ==== Check if participant already exists ====
    let participantState = await stub.getState(participantEmailId);
    if (participantState.toString()) {
      throw new Error('This participant already exists: ' + participantEmailId);
    }

    // ==== Create participant object and marshal to JSON ====
    let participant = {};
    participant.docType = 'participant';
    participant.emailId = participantEmailId;
    participant.name = participantName;
    participant.status = 'NEW';

    // === Save participant to state ===
    await stub.putState(participantEmailId, Buffer.from(JSON.stringify(participant)));

    // ==== participant saved. Return success ====
    console.info('- end init participant');
  }

  // ===============================================
  // readObject - read a participant/patient/consent from chaincode state
  // ===============================================
  async readObject(stub, args, thisClass) {
    if (args.length != 1) {
      throw new Error('Incorrect number of arguments. Expecting id of the object to query');
    }

    let id = args[0];

    if (!id) {
      throw new Error(' id must not be empty');
    }
    console.info("quering "+id);
    let objectAsbytes = await stub.getState(id); //get the marble from chaincode state
    if (!objectAsbytes.toString()) {
      let jsonResp = {};
      jsonResp.Error = 'Object does not exist: ' + id;
      throw new Error(JSON.stringify(jsonResp));
    }
    console.info('=======================================');
    console.log(objectAsbytes.toString());
    console.info('=======================================');
    return objectAsbytes;
  }

  // ===========================================================
  // verify participant
  // ===========================================================
  async verifyParticipant(stub, args, thisClass) {

    if (args.length < 1) {
      throw new Error('Incorrect number of arguments. Expecting participant id')
    }

    let participantEmailId = args[0];

    console.info('- start verifying participant ', participantEmailId);

    let participantAsBytes = await stub.getState(participantEmailId);
    if (!participantAsBytes || !participantAsBytes.toString()) {
      throw new Error('Participant does not exist');
    }
    let participantToUpdate = {};
    try {
      participantToUpdate = JSON.parse(participantAsBytes.toString()); //unmarshal
    } catch (err) {
      let jsonResp = {};
      jsonResp.error = 'Failed to decode JSON of: ' + participantEmailId;
      throw new Error(jsonResp);
    }
    console.info(participantToUpdate);
    participantToUpdate.status = 'VERIFIED'; //change the status to ACCEPTED

    let participantJSONasBytes = Buffer.from(JSON.stringify(participantToUpdate));
    await stub.putState(participantEmailId, participantJSONasBytes); //rewrite the consent

    console.info('- end provideConsent (success)');
  }
};

shim.start(new Chaincode());
