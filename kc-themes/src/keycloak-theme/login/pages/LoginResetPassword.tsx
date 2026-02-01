import { useState } from "react";
import type { PageProps } from "keycloakify/login/pages/PageProps";
import type { KcContext } from "../KcContext";
import type { I18n } from "../i18n";

export default function LoginResetPassword(
  props: PageProps<Extract<KcContext, { pageId: "login-reset-password.ftl" }>, I18n>
) {
  const { kcContext, i18n, doUseDefaultCss, Template, classes } = props;
  const { url, realm, messagesPerField } = kcContext;
  const { msg, msgStr } = i18n;

  const [isFormSubmitted, setIsFormSubmitted] = useState(false);

  return (
    <Template
      kcContext={kcContext}
      i18n={i18n}
      doUseDefaultCss={doUseDefaultCss}
      classes={classes}
      displayMessage={!messagesPerField.existsError("username")}
      headerNode={
        <div className="finappkc-header-content">
          <h1 className="finappkc-title">{msg("emailForgotTitle")}</h1>
        </div>
      }
    >
      <div className="finappkc-form-wrapper">
        <p className="finappkc-subtitle" style={{ textAlign: "center", marginBottom: "1.5rem" }}>
          {msg("emailInstruction")}
        </p>

        <form
          className="finappkc-form"
          action={url.loginAction}
          method="post"
          onSubmit={() => setIsFormSubmitted(true)}
        >
          <div className="finappkc-form-group">
            <label htmlFor="username" className="finappkc-label">
              {!realm.loginWithEmailAllowed
                ? msg("username")
                : !realm.registrationEmailAsUsername
                  ? msg("usernameOrEmail")
                  : msg("email")}
            </label>
            <input
              type="text"
              id="username"
              name="username"
              className="finappkc-input"
              autoFocus
              autoComplete="username"
              aria-invalid={messagesPerField.existsError("username")}
            />
            {messagesPerField.existsError("username") && (
              <span className="finappkc-error">
                {messagesPerField.getFirstError("username")}
              </span>
            )}
          </div>

          <div className="finappkc-form-actions">
            <button
              type="submit"
              className="finappkc-btn finappkc-btn-primary finappkc-btn-block"
              disabled={isFormSubmitted}
            >
              {msgStr("doSubmit")}
            </button>
          </div>
        </form>

        <div className="finappkc-register" style={{ marginTop: "1.5rem" }}>
          <a href={url.loginUrl} className="finappkc-link">
            {msg("backToLogin")}
          </a>
        </div>
      </div>
    </Template>
  );
}
