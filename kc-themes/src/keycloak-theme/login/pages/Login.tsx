import { useState } from "react";
import type { PageProps } from "keycloakify/login/pages/PageProps";
import type { KcContext } from "../KcContext";
import type { I18n } from "../i18n";

export default function Login(
  props: PageProps<Extract<KcContext, { pageId: "login.ftl" }>, I18n>
) {
  const { kcContext, i18n, doUseDefaultCss, Template, classes } = props;
  const { realm, url, usernameHidden, login, social } = kcContext;
  const { msg, msgStr } = i18n;

  const [isLoginButtonDisabled, setIsLoginButtonDisabled] = useState(false);

  return (
    <Template
      kcContext={kcContext}
      i18n={i18n}
      doUseDefaultCss={doUseDefaultCss}
      classes={classes}
      displayMessage={!kcContext.messagesPerField?.existsError("username", "password")}
      headerNode={
        <div className="finappkc-header-content">
          <h1 className="finappkc-title">
            {msg("loginAccountTitle")}
          </h1>
        </div>
      }
      socialProvidersNode={
        social?.providers && social.providers.length > 0 ? (
          <div className="finappkc-social-providers">
            <div className="finappkc-divider">
              <span>{msg("identity-provider-login-label")}</span>
            </div>
            <ul className="finappkc-social-list">
              {social.providers.map((p) => (
                <li key={p.alias}>
                  <a
                    href={p.loginUrl}
                    className="finappkc-social-link"
                    id={`social-${p.alias}`}
                  >
                    {p.displayName}
                  </a>
                </li>
              ))}
            </ul>
          </div>
        ) : null
      }
    >
      <div className="finappkc-form-wrapper">
        <form
          className="finappkc-form"
          onSubmit={() => {
            setIsLoginButtonDisabled(true);
            return true;
          }}
          action={url.loginAction}
          method="post"
        >
          {/* Username/Email field */}
          {!usernameHidden && (
            <div className="finappkc-form-group">
              <label htmlFor="username" className="finappkc-label">
                {!realm.loginWithEmailAllowed
                  ? msg("username")
                  : !realm.registrationEmailAsUsername
                    ? msg("usernameOrEmail")
                    : msg("email")}
              </label>
              <input
                tabIndex={2}
                id="username"
                className="finappkc-input"
                name="username"
                defaultValue={login.username ?? ""}
                type="text"
                autoFocus
                autoComplete="username"
                aria-invalid={
                  kcContext.messagesPerField?.existsError("username")
                }
              />
              {kcContext.messagesPerField?.existsError("username") && (
                <span className="finappkc-error">
                  {kcContext.messagesPerField.getFirstError("username")}
                </span>
              )}
            </div>
          )}

          {/* Password field */}
          <div className="finappkc-form-group">
            <label htmlFor="password" className="finappkc-label">
              {msg("password")}
            </label>
            <input
              tabIndex={3}
              id="password"
              className="finappkc-input"
              name="password"
              type="password"
              autoComplete="current-password"
              aria-invalid={
                kcContext.messagesPerField?.existsError("password")
              }
            />
            {kcContext.messagesPerField?.existsError("password") && (
              <span className="finappkc-error">
                {kcContext.messagesPerField.getFirstError("password")}
              </span>
            )}
          </div>

          {/* Remember me & Forgot password */}
          <div className="finappkc-form-options">
            {realm.rememberMe && !usernameHidden && (
              <div className="finappkc-checkbox-wrapper">
                <input
                  tabIndex={5}
                  id="rememberMe"
                  name="rememberMe"
                  type="checkbox"
                  defaultChecked={!!login.rememberMe}
                  className="finappkc-checkbox"
                />
                <label htmlFor="rememberMe" className="finappkc-checkbox-label">
                  {msg("rememberMe")}
                </label>
              </div>
            )}

            {realm.resetPasswordAllowed && (
              <a
                tabIndex={6}
                href={url.loginResetCredentialsUrl}
                className="finappkc-link"
              >
                {msg("doForgotPassword")}
              </a>
            )}
          </div>

          {/* Submit button */}
          <div className="finappkc-form-actions">
            <input type="hidden" id="id-hidden-input" name="credentialId" />
            <button
              tabIndex={7}
              className="finappkc-btn finappkc-btn-primary finappkc-btn-block"
              name="login"
              id="kc-login"
              type="submit"
              disabled={isLoginButtonDisabled}
            >
              {msgStr("doLogIn")}
            </button>
          </div>
        </form>

      </div>
    </Template>
  );
}
