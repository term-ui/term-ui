import { defineProject } from "vitest/config";

export default defineProject({
  test: {
    include: ["**/*.test.ts"],
    exclude: [
      "**/node_modules/**",
      "**/dist/**",
      "**/build/**",
    ],
  },
});
