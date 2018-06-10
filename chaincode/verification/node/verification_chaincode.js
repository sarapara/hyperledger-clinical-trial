
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
  // initDoctor - Onboard Doctor
  // ===============================================
  async initDoctor(stub, args, thisClass) {
    if (args.length != 2) {
      throw new Error('Incorrect number of arguments. Expecting 2');
    }
    // ==== Input sanitation ====
    console.info('--- start init doctor ---')
    if (args[0].length <= 0) {
      throw new Error('1st argument must be a non-empty string');
    }
    if (args[1].length <= 0) {
      throw new Error('2nd argument must be a non-empty string');
    }

    let docEmailId = args[0].toLowerCase();
    let docName = args[1].toLowerCase();

    // ==== Check if doctor already exists ====
    let doctorState = await stub.getState(docEmailId);
    if (doctorState.toString()) {
      throw new Error('This doctor already exists: ' + docEmailId);
    }

    // ==== Create doctor object and marshal to JSON ====
    let doctor = {};
    doctor.docType = 'doctor';
    doctor.emailId = docEmailId;
    doctor.name = docName;

    // === Save doctor to state ===
    await stub.putState(docName, Buffer.from(JSON.stringify(doctor)));

    // ==== Doctor saved. Return success ====
    console.info('- end init doctor');
  }

  // ===============================================
  // initPatient - Onboard Patient
  // ===============================================
  async initPatient(stub, args, thisClass) {
    if (args.length != 2) {
      throw new Error('Incorrect number of arguments. Expecting 2');
    }
    // ==== Input sanitation ====
    console.info('--- start init doctor ---')
    if (args[0].length <= 0) {
      throw new Error('1st argument must be a non-empty string');
    }
    if (args[1].length <= 0) {
      throw new Error('2nd argument must be a non-empty string');
    }
    if (args[2].length <= 0) {
      throw new Error('3rd argument must be a non-empty string');
    }

    let patientEmailId = args[0].toLowerCase();
    let patientName = args[1].toLowerCase();
    let patientDoctor = args[2].toLowerCase();

    // ==== Check if patient already exists ====
    let patientState = await stub.getState(patientEmailId);
    if (patientState.toString()) {
      throw new Error('This patient already exists: ' + patientEmailId);
    }

    // ==== Ensure doctor already exists ====
    let patientDoctorState = await stub.getState(patientDoctor);
    if (!patientDoctorState.toString()) {
      throw new Error('This doctor does not exist: ' + patientDoctor);
    }

    // ==== Create patient object and marshal to JSON ====
    let patient = {};
    patient.docType = 'patient';
    patient.emailId = patientEmailId;
    patient.name = patientName;
    patient.doctor = patientDoctor;

    // === Save doctor to state ===
    await stub.putState(patientEmailId, Buffer.from(JSON.stringify(patient)));

    // ==== Patient saved. Return success ====
    console.info('- end init patient');
  }



  // ===============================================
  // readObject - read a doctor/patient/consent from chaincode state
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
  // patient provides consent
  // ===========================================================
  async provideConsent(stub, args, thisClass) {

    if (args.length < 2) {
      throw new Error('Incorrect number of arguments. Expecting consentid and patient')
    }

    let consentId = args[0];
    let patient = args[1].toLowerCase();

    console.info('- start setup consent ', consentId, patient);

    let consentAsBytes = await stub.getState(consentId);
    if (!consentAsBytes || !consentAsBytes.toString()) {
      throw new Error('consent does not exist');
    }
    let consentToUpdate = {};
    try {
      consentToUpdate = JSON.parse(consentAsBytes.toString()); //unmarshal
    } catch (err) {
      let jsonResp = {};
      jsonResp.error = 'Failed to decode JSON of: ' + consentId;
      throw new Error(jsonResp);
    }
    console.info(consentToUpdate);
    consentToUpdate.status = 'ACCEPTED'; //change the status to ACCEPTED

    let consentJSONasBytes = Buffer.from(JSON.stringify(consentToUpdate));
    await stub.putState(consentId, consentJSONasBytes); //rewrite the consent

    console.info('- end provideConsent (success)');
  }

  // ===========================================================
  // doctor co-signs consent
  // ===========================================================
  async coSignConsent(stub, args, thisClass) {

    // cosignConsentData.consent.status = "COSIGNED";
    // cosignConsentData.consent.coSignee = doc;

    if (args.length < 2) {
      throw new Error('Incorrect number of arguments. Expecting consentid, doctor')
    }

    let consentId = args[0];
    let doctor = args[1].toLowerCase();

    console.info('- start cosign consent ', consentId, doctor);

    let consentAsBytes = await stub.getState(consentId);
    if (!consentAsBytes || !consentAsBytes.toString()) {
      throw new Error('consent does not exist');
    }
    let consentToUpdate = {};
    try {
      consentToUpdate = JSON.parse(consentAsBytes.toString()); //unmarshal
    } catch (err) {
      let jsonResp = {};
      jsonResp.error = 'Failed to decode JSON of: ' + consentId;
      throw new Error(jsonResp);
    }
    console.info(consentToUpdate);
    consentToUpdate.coSignee = doctor;
    consentToUpdate.status = 'COSIGNED'; //change the status to ACCEPTED

    let consentJSONasBytes = Buffer.from(JSON.stringify(consentToUpdate));
    await stub.putState(consentId, consentJSONasBytes); //rewrite the consent

    console.info('- end coSignConsent (success)');
  }

  // ===========================================================================================
  // getMarblesByRange performs a range query based on the start and end keys provided.

  // Read-only function results are not typically submitted to ordering. If the read-only
  // results are submitted to ordering, or if the query is used in an update transaction
  // and submitted to ordering, then the committing peers will re-execute to guarantee that
  // result sets are stable between endorsement time and commit time. The transaction is
  // invalidated by the committing peers if the result set has changed between endorsement
  // time and commit time.
  // Therefore, range queries are a safe option for performing update transactions based on query results.
  // ===========================================================================================
  async getMarblesByRange(stub, args, thisClass) {

    if (args.length < 2) {
      throw new Error('Incorrect number of arguments. Expecting 2');
    }

    let startKey = args[0];
    let endKey = args[1];

    let resultsIterator = await stub.getStateByRange(startKey, endKey);
    let method = thisClass['getAllResults'];
    let results = await method(resultsIterator, false);

    return Buffer.from(JSON.stringify(results));
  }

  // ==== Example: GetStateByPartialCompositeKey/RangeQuery =========================================
  // transferMarblesBasedOnColor will transfer marbles of a given color to a certain new owner.
  // Uses a GetStateByPartialCompositeKey (range query) against color~name 'index'.
  // Committing peers will re-execute range queries to guarantee that result sets are stable
  // between endorsement time and commit time. The transaction is invalidated by the
  // committing peers if the result set has changed between endorsement time and commit time.
  // Therefore, range queries are a safe option for performing update transactions based on query results.
  // ===========================================================================================
  async transferMarblesBasedOnColor(stub, args, thisClass) {

    //   0       1
    // 'color', 'bob'
    if (args.length < 2) {
      throw new Error('Incorrect number of arguments. Expecting color and owner');
    }

    let color = args[0];
    let newOwner = args[1].toLowerCase();
    console.info('- start transferMarblesBasedOnColor ', color, newOwner);

    // Query the color~name index by color
    // This will execute a key range query on all keys starting with 'color'
    let coloredMarbleResultsIterator = await stub.getStateByPartialCompositeKey('color~name', [color]);

    let method = thisClass['transferMarble'];
    // Iterate through result set and for each marble found, transfer to newOwner
    while (true) {
      let responseRange = await coloredMarbleResultsIterator.next();
      if (!responseRange || !responseRange.value || !responseRange.value.key) {
        return;
      }
      console.log(responseRange.value.key);

      // let value = res.value.value.toString('utf8');
      let objectType;
      let attributes;
      ({
        objectType,
        attributes
      } = await stub.splitCompositeKey(responseRange.value.key));

      let returnedColor = attributes[0];
      let returnedMarbleName = attributes[1];
      console.info(util.format('- found a marble from index:%s color:%s name:%s\n', objectType, returnedColor, returnedMarbleName));

      // Now call the transfer function for the found marble.
      // Re-use the same function that is used to transfer individual marbles
      let response = await method(stub, [returnedMarbleName, newOwner]);
    }

    let responsePayload = util.format('Transferred %s marbles to %s', color, newOwner);
    console.info('- end transferMarblesBasedOnColor: ' + responsePayload);
  }


  // ===== Example: Parameterized rich query =================================================
  // queryMarblesByOwner queries for marbles based on a passed in owner.
  // This is an example of a parameterized query where the query logic is baked into the chaincode,
  // and accepting a single query parameter (owner).
  // Only available on state databases that support rich query (e.g. CouchDB)
  // =========================================================================================
  async queryMarblesByOwner(stub, args, thisClass) {
    //   0
    // 'bob'
    if (args.length < 1) {
      throw new Error('Incorrect number of arguments. Expecting owner name.')
    }

    let owner = args[0].toLowerCase();
    let queryString = {};
    queryString.selector = {};
    queryString.selector.docType = 'marble';
    queryString.selector.owner = owner;
    let method = thisClass['getQueryResultForQueryString'];
    let queryResults = await method(stub, JSON.stringify(queryString), thisClass);
    return queryResults; //shim.success(queryResults);
  }

  // ===== Example: Ad hoc rich query ========================================================
  // queryMarbles uses a query string to perform a query for marbles.
  // Query string matching state database syntax is passed in and executed as is.
  // Supports ad hoc queries that can be defined at runtime by the client.
  // If this is not desired, follow the queryMarblesForOwner example for parameterized queries.
  // Only available on state databases that support rich query (e.g. CouchDB)
  // =========================================================================================
  async queryMarbles(stub, args, thisClass) {
    //   0
    // 'queryString'
    if (args.length < 1) {
      throw new Error('Incorrect number of arguments. Expecting queryString');
    }
    let queryString = args[0];
    if (!queryString) {
      throw new Error('queryString must not be empty');
    }
    let method = thisClass['getQueryResultForQueryString'];
    let queryResults = await method(stub, queryString, thisClass);
    return queryResults;
  }

  async getAllResults(iterator, isHistory) {
    let allResults = [];
    while (true) {
      let res = await iterator.next();

      if (res.value && res.value.value.toString()) {
        let jsonRes = {};
        console.log(res.value.value.toString('utf8'));

        if (isHistory && isHistory === true) {
          jsonRes.TxId = res.value.tx_id;
          jsonRes.Timestamp = res.value.timestamp;
          jsonRes.IsDelete = res.value.is_delete.toString();
          try {
            jsonRes.Value = JSON.parse(res.value.value.toString('utf8'));
          } catch (err) {
            console.log(err);
            jsonRes.Value = res.value.value.toString('utf8');
          }
        } else {
          jsonRes.Key = res.value.key;
          try {
            jsonRes.Record = JSON.parse(res.value.value.toString('utf8'));
          } catch (err) {
            console.log(err);
            jsonRes.Record = res.value.value.toString('utf8');
          }
        }
        allResults.push(jsonRes);
      }
      if (res.done) {
        console.log('end of data');
        await iterator.close();
        console.info(allResults);
        return allResults;
      }
    }
  }

  // =========================================================================================
  // getQueryResultForQueryString executes the passed in query string.
  // Result set is built and returned as a byte array containing the JSON results.
  // =========================================================================================
  async getQueryResultForQueryString(stub, queryString, thisClass) {

    console.info('- getQueryResultForQueryString queryString:\n' + queryString)
    let resultsIterator = await stub.getQueryResult(queryString);
    let method = thisClass['getAllResults'];

    let results = await method(resultsIterator, false);

    return Buffer.from(JSON.stringify(results));
  }

  async getHistoryForMarble(stub, args, thisClass) {

    if (args.length < 1) {
      throw new Error('Incorrect number of arguments. Expecting 1')
    }
    let marbleName = args[0];
    console.info('- start getHistoryForMarble: %s\n', marbleName);

    let resultsIterator = await stub.getHistoryForKey(marbleName);
    let method = thisClass['getAllResults'];
    let results = await method(resultsIterator, true);

    return Buffer.from(JSON.stringify(results));
  }
};

shim.start(new Chaincode());
