import type { PageProps } from "keycloakify/login/pages/PageProps";
import type { KcContext } from "../KcContext";
import type { I18n } from "../i18n";

export default function Error(
  props: PageProps<Extract<KcContext, { pageId: "error.ftl" }>, I18n>
) {
  const { kcContext, i18n, doUseDefaultCss, Template, classes } = props;
  const { message, client } = kcContext;
  const { msg } = i18n;

  return (
    <Template
      kcContext={kcContext}
      i18n={i18n}
      doUseDefaultCss={doUseDefaultCss}
      classes={classes}
      displayMessage={false}
      headerNode={
        <div className="finappkc-header-content">
          <h1 className="finappkc-title finappkc-error-title">
            {msg("errorTitle")}
          </h1>
        </div>
      }
    >
      <div className="finappkc-error-page">
        <div className="finappkc-error-icon">
          <svg
            xmlns="http://www.w3.org/2000/svg"
            width="64"
            height="64"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            strokeWidth="2"
            strokeLinecap="round"
            strokeLinejoin="round"
          >
            <circle cx="12" cy="12" r="10" />
            <line x1="12" y1="8" x2="12" y2="12" />
            <line x1="12" y1="16" x2="12.01" y2="16" />
          </svg>
        </div>

        <div className="finappkc-error-message">
          <p
            dangerouslySetInnerHTML={{
              __html: message.summary,
            }}
          />
        </div>

        {client?.baseUrl && (
          <div className="finappkc-error-actions">
            <a
              href={client.baseUrl}
              className="finappkc-btn finappkc-btn-primary"
            >
              {msg("backToApplication")}
            </a>
          </div>
        )}
      </div>
    </Template>
  );
}
