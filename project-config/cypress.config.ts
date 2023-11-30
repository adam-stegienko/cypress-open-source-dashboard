// cypress.config.ts
import { defineConfig } from "cypress";
import { cloudPlugin } from "cypress-cloud/plugin";

export default defineConfig({
  e2e: {
    reporter: 'junit',
    reporterOptions: {
      mochaFile: 'results/cypress-results-[hash].xml',
      toConsole: true,
    },
    baseUrl: process.env.BASE_URL,
    video: true,
    videoCompression: 32,
    screenshotOnRunFailure: true,
    specPattern: "cypress/e2e/*.cy.ts",
    async setupNodeEvents(on: any, config: any) {
      const result = await cloudPlugin(on, config);
      return result;
    },
  },
  screenshotsFolder: 'results/screenshots',
  videosFolder: 'results/videos',
});