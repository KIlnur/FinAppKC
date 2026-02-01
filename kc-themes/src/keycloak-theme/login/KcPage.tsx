import { Suspense, lazy } from "react";
import type { ClassKey } from "keycloakify/login";
import type { KcContext } from "./KcContext";
import { useI18n } from "./i18n";
import DefaultPage from "keycloakify/login/DefaultPage";
import Template from "keycloakify/login/Template";
import "./main.css";

// Lazy load custom pages
const Login = lazy(() => import("./pages/Login"));
const LoginResetPassword = lazy(() => import("./pages/LoginResetPassword"));
const LoginOtp = lazy(() => import("./pages/LoginOtp"));
const Error = lazy(() => import("./pages/Error"));

// Lazy load required components
const UserProfileFormFields = lazy(
  () => import("keycloakify/login/UserProfileFormFields")
);

// Custom CSS classes
const classes: { [key in ClassKey]?: string } = {
  kcHtmlClass: "finappkc-html",
  kcBodyClass: "finappkc-body",
  kcLoginClass: "finappkc-login",
  kcFormCardClass: "finappkc-card",
  kcButtonClass: "finappkc-btn",
  kcButtonPrimaryClass: "finappkc-btn-primary",
  kcInputClass: "finappkc-input",
  kcLabelClass: "finappkc-label",
};

export default function KcPage(props: { kcContext: KcContext }) {
  const { kcContext } = props;
  const { i18n } = useI18n({ kcContext });

  return (
    <Suspense fallback={<div className="finappkc-loading">Loading...</div>}>
      {(() => {
        switch (kcContext.pageId) {
          // Custom pages
          case "login.ftl":
            return (
              <Login
                kcContext={kcContext}
                i18n={i18n}
                classes={classes}
                Template={Template}
                doUseDefaultCss={true}
              />
            );
          case "login-reset-password.ftl":
            return (
              <LoginResetPassword
                kcContext={kcContext}
                i18n={i18n}
                classes={classes}
                Template={Template}
                doUseDefaultCss={true}
              />
            );
          case "login-otp.ftl":
            return (
              <LoginOtp
                kcContext={kcContext}
                i18n={i18n}
                classes={classes}
                Template={Template}
                doUseDefaultCss={true}
              />
            );
          case "error.ftl":
            return (
              <Error
                kcContext={kcContext}
                i18n={i18n}
                classes={classes}
                Template={Template}
                doUseDefaultCss={true}
              />
            );
          // WebAuthn pages - use default Keycloak implementation
          // All other pages - use default
          default:
            return (
              <DefaultPage
                kcContext={kcContext}
                i18n={i18n}
                classes={classes}
                Template={Template}
                doUseDefaultCss={true}
                UserProfileFormFields={UserProfileFormFields}
                doMakeUserConfirmPassword={true}
              />
            );
        }
      })()}
    </Suspense>
  );
}
