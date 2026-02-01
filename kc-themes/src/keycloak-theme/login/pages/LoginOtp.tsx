import { useState } from "react";
import type { PageProps } from "keycloakify/login/pages/PageProps";
import type { KcContext } from "../KcContext";
import type { I18n } from "../i18n";

export default function LoginOtp(
  props: PageProps<Extract<KcContext, { pageId: "login-otp.ftl" }>, I18n>
) {
  const { kcContext, i18n, doUseDefaultCss, Template, classes } = props;
  const { url, messagesPerField, otpLogin } = kcContext;
  const { msg, msgStr } = i18n;

  const [isFormSubmitted, setIsFormSubmitted] = useState(false);

  return (
    <Template
      kcContext={kcContext}
      i18n={i18n}
      doUseDefaultCss={doUseDefaultCss}
      classes={classes}
      displayMessage={!messagesPerField.existsError("totp")}
      headerNode={
        <div className="finappkc-header-content">
          <h1 className="finappkc-title">{msg("doLogIn")}</h1>
        </div>
      }
    >
      <div className="finappkc-form-wrapper">
        <p className="finappkc-subtitle" style={{ textAlign: "center", marginBottom: "1.5rem" }}>
          {msg("loginOtpOneTime", "Enter one-time code from your authenticator app")}
        </p>

        <form
          className="finappkc-form"
          action={url.loginAction}
          method="post"
          onSubmit={() => setIsFormSubmitted(true)}
        >
          {/* OTP Device Selection (if multiple) */}
          {otpLogin.userOtpCredentials.length > 1 && (
            <div className="finappkc-form-group">
              <label className="finappkc-label">Select device</label>
              <div className="finappkc-otp-devices">
                {otpLogin.userOtpCredentials.map((credential, index) => (
                  <div key={credential.id} className="finappkc-radio-wrapper">
                    <input
                      type="radio"
                      id={`otp-${credential.id}`}
                      name="selectedCredentialId"
                      value={credential.id}
                      defaultChecked={index === 0}
                      className="finappkc-radio"
                    />
                    <label htmlFor={`otp-${credential.id}`} className="finappkc-radio-label">
                      {credential.userLabel ?? `Device ${index + 1}`}
                    </label>
                  </div>
                ))}
              </div>
            </div>
          )}

          {/* Single device - hidden input */}
          {otpLogin.userOtpCredentials.length === 1 && (
            <input
              type="hidden"
              name="selectedCredentialId"
              value={otpLogin.userOtpCredentials[0].id}
            />
          )}

          {/* OTP Input */}
          <div className="finappkc-form-group">
            <label htmlFor="otp" className="finappkc-label">
              {msg("loginOtpOneTime", "One-time code")} <span className="required">*</span>
            </label>
            <input
              type="text"
              id="otp"
              name="otp"
              className="finappkc-input finappkc-otp-input"
              autoComplete="one-time-code"
              autoFocus
              inputMode="numeric"
              pattern="[0-9]*"
              maxLength={6}
              placeholder="000000"
              aria-invalid={messagesPerField.existsError("totp")}
            />
            {messagesPerField.existsError("totp") && (
              <span className="finappkc-error">
                {messagesPerField.getFirstError("totp")}
              </span>
            )}
          </div>

          <div className="finappkc-form-actions">
            <button
              type="submit"
              className="finappkc-btn finappkc-btn-primary finappkc-btn-block"
              disabled={isFormSubmitted}
            >
              {msgStr("doLogIn")}
            </button>
          </div>
        </form>
      </div>
    </Template>
  );
}
