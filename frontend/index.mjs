import {cognitoLoginUrl, clientId, APIURL} from "./config.mjs";
import ReactDOM from "react-dom";
import {App} from "./App.mjs";
import {processLoginFlow, redirectToLogin, redirectToLogout, getValidTokens } from "./cognito-utils.mjs";
import htm from "htm";
import React from "react";

const html = htm.bind(React.createElement);

const serialize = (fn) => {
	let queue = Promise.resolve();
	return (...args) => {
		const res = queue.then(() => fn(...args));
		queue = res.catch(() => {});
		return res;
	};
};

processLoginFlow(cognitoLoginUrl, clientId)((initialTokens) => {
	const getAccessToken = ((initialTokens) => {
		let tokens = initialTokens;
		return serialize(async () => {
			tokens = await getValidTokens(cognitoLoginUrl, clientId, tokens);
			return tokens.access_token;
		});
	})(initialTokens);

	ReactDOM.createRoot(document.getElementById("content")).render(html`
		<${App}
			APIURL=${APIURL}
			loggedin=${!!initialTokens}
			getAccessToken=${getAccessToken}
			redirectToLogin=${() => redirectToLogin(cognitoLoginUrl, clientId)}
			redirectToLogout=${() => redirectToLogout(cognitoLoginUrl, clientId)}
		/>
	`);
});

