# Project Config

Project config for reference. Use it in your JavaScript project, placing it inside the root project dir so you can start working with the open-source Cypress dashboard to save your tests results in.

These include:
- `.env.local` file with env variables for configs
- customized `cypress.config.ts` for basic Cypress set-up in TypeScript projects
- `currents.config.js` file containing the open-source Cypress dashboard's configuration

Next, make sure to add `cypress` and `cypress-cloud` packages to your npm project, then run: 
`npx cypress-cloud run --record --key <matching-key-with-currents-config> --ci-build-id <unique-build-id>` to start a test run session.

If any problem with the dashboard's certificate occurs, run: 
`export NODE_EXTRA_CA_CERTS=/etc/ssl/certs/<your-ca-pem-certificate-name>` and run the previous command again.

Optionally, you can also add the starting command to your npm scripts section within the `package.json` file.