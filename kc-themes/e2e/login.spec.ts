import { test, expect } from "@playwright/test";

test.describe("Login Page", () => {
  test.beforeEach(async ({ page }) => {
    // Navigate to login page
    await page.goto("/realms/finapp/protocol/openid-connect/auth?client_id=finapp-web&response_type=code&redirect_uri=http://localhost:3000");
  });

  test("should display login form", async ({ page }) => {
    // Check for username/email field
    await expect(page.locator("#username")).toBeVisible();
    
    // Check for password field
    await expect(page.locator("#password")).toBeVisible();
    
    // Check for submit button
    await expect(page.locator("#kc-login")).toBeVisible();
  });

  test("should show error for invalid credentials", async ({ page }) => {
    // Fill in invalid credentials
    await page.fill("#username", "invalid@example.com");
    await page.fill("#password", "wrongpassword");
    
    // Submit form
    await page.click("#kc-login");
    
    // Check for error message
    await expect(page.locator(".finapp-alert-error, .alert-error")).toBeVisible();
  });

  test("should have working forgot password link", async ({ page }) => {
    // Click forgot password
    const forgotLink = page.locator('a[href*="login-reset-credentials"]');
    
    if (await forgotLink.isVisible()) {
      await forgotLink.click();
      await expect(page).toHaveURL(/login-reset-credentials/);
    }
  });

  test("should have working registration link", async ({ page }) => {
    // Click register link if visible
    const registerLink = page.locator('a[href*="registration"]');
    
    if (await registerLink.isVisible()) {
      await registerLink.click();
      await expect(page).toHaveURL(/registration/);
    }
  });

  test("should support language switching", async ({ page }) => {
    // Check if language selector exists
    const langSelector = page.locator(".finapp-language-select, select[name='locale']");
    
    if (await langSelector.isVisible()) {
      // Switch to Russian
      await langSelector.selectOption("ru");
      
      // Verify page updated
      await expect(page.locator("html")).toHaveAttribute("lang", "ru");
    }
  });
});

test.describe("Registration Page", () => {
  test("should display registration form", async ({ page }) => {
    await page.goto("/realms/finapp/protocol/openid-connect/registrations?client_id=finapp-web&response_type=code&redirect_uri=http://localhost:3000");
    
    // Check for required fields
    await expect(page.locator("#firstName")).toBeVisible();
    await expect(page.locator("#lastName")).toBeVisible();
    await expect(page.locator("#email")).toBeVisible();
    await expect(page.locator("#password")).toBeVisible();
  });
});

test.describe("Accessibility", () => {
  test("login form should be accessible", async ({ page }) => {
    await page.goto("/realms/finapp/protocol/openid-connect/auth?client_id=finapp-web&response_type=code&redirect_uri=http://localhost:3000");
    
    // Check for proper labels
    const usernameLabel = page.locator('label[for="username"]');
    await expect(usernameLabel).toBeVisible();
    
    const passwordLabel = page.locator('label[for="password"]');
    await expect(passwordLabel).toBeVisible();
    
    // Check for form role
    const form = page.locator("form#kc-form-login");
    await expect(form).toBeVisible();
  });
});
