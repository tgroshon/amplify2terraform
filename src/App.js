import React from "react";

import AWSAppSyncClient, { AUTH_TYPE } from "aws-appsync";
import { Rehydrated } from "aws-appsync-react";
import Amplify, { Auth } from "aws-amplify";
import { withAuthenticator } from "aws-amplify-react";
import { ApolloProvider, Query } from "react-apollo";

import gql from "graphql-tag";

import logo from "./logo.svg";
import "./App.css";

import awsConfig from "./aws-exports";

Amplify.configure(awsConfig);

const client = new AWSAppSyncClient({
  url: awsConfig.aws_appsync_graphqlEndpoint,
  region: awsConfig.aws_appsync_region,
  auth: {
    type: AUTH_TYPE.AMAZON_COGNITO_USER_POOLS,
    jwtToken: async () =>
      (await Auth.currentSession()).getIdToken().getJwtToken()
  }
});

const LIST_WORKERS = gql`
  query ListWorkers(
    $filter: ModelWorkerFilterInput
    $limit: Int
    $nextToken: String
  ) {
    listWorkers(filter: $filter, limit: $limit, nextToken: $nextToken) {
      items {
        id
        name
        phone
        type
      }
      nextToken
    }
  }
`;

function App() {
  return (
    <Query query={LIST_WORKERS}>
      {({ loading, error, data }) => {
        if (error) {
          console.error("Error listing workers", error);
        }

        if (data) {
          console.log("Data for workers graphql query", data);
        }

        let message = `Found ${
          data && data.listWorkers ? data.listWorkers.items.length : 0
        } workers`;

        return (
          <div className="App">
            <header className="App-header">
              <img src={logo} className="App-logo" alt="logo" />
              <p>
                Edit <code>src/App.js</code> and save to reload.
              </p>
              <a
                className="App-link"
                href="https://reactjs.org"
                target="_blank"
                rel="noopener noreferrer"
              >
                Learn React
              </a>
              <h4>{loading ? "Loading..." : ""}</h4>
              <h3>{message}</h3>
            </header>
          </div>
        );
      }}
    </Query>
  );
}

function Wrapper({ authData }) {
  console.log("Your user authData", authData);
  return (
    <ApolloProvider client={client}>
      <Rehydrated>
        <App />
      </Rehydrated>
    </ApolloProvider>
  );
}

export default withAuthenticator(Wrapper);
