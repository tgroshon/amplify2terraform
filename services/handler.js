"use strict";

const AWS = require("aws-sdk");
const attr = require("dynamodb-data-types").AttributeValue;

// ENV VARS
const STAGE = process.env.STAGE;
const WORKER_TABLE = process.env.WORKER_TABLE;

const dynamo = new AWS.DynamoDB();

async function notifier(event) {
  console.log("Got event", event);

  let { id } = event.arguments;
  let params = {
    TableName: WORKER_TABLE,
    Key: attr.wrap({ id })
  };

  console.log("Querying worker data", params);
  let { Item } = await dynamo.getItem(params).promise();
  let worker = attr.unwrap(Item);
  console.log("Got worker", worker);

  // TODO: Do something to notify your worker of ... whatever

  return { result: "success", message: `Got worker with name ${worker.name}` };
}

module.exports = {
  notifier
};
