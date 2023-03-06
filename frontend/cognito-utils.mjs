const sha256 = async (str) => {
	return await crypto.subtle.digest("SHA-256", new TextEncoder().encode(str));
};

const generateNonce = () => [...crypto.getRandomValues(new Uint8Array(16))].map((v) => v.toString(16).padStart(2, "0")).join("");

const base64URLEncode = (string) => {
	return btoa(String.fromCharCode.apply(null, new Uint8Array(string)))
		.replace(/\+/g, "-")
		.replace(/\//g, "_")
		.replace(/=+$/, "");
};

const base64URLDecode = (string) => {
	return atob(string
		.replace(/-/g, "+")
		.replace(/_/g, "/") +
		"=".repeat((4 - string.length % 4) % 4));
};

export const redirectToLogin = async (cognitoLoginUrl, clientId) => {
	const state = generateNonce();
	const codeVerifier = generateNonce();
	sessionStorage.setItem(`codeVerifier-${state}`, codeVerifier);
	const codeChallenge = base64URLEncode(await sha256(codeVerifier));
	window.location = `${cognitoLoginUrl}/login?response_type=code&client_id=${clientId}&state=${state}&code_challenge_method=S256&code_challenge=${codeChallenge}&redirect_uri=${window.location.origin}`;
};

export const redirectToLogout = async (cognitoLoginUrl, clientId) => {
	localStorage.removeItem("tokens");
	window.location = `${cognitoLoginUrl}/logout?client_id=${clientId}&logout_uri=${window.location.origin}`;
};

export const getValidTokens = async (cognitoLoginUrl, clientId, tokens) => {
	const {exp} = JSON.parse(base64URLDecode(tokens.access_token.split(".")[1]));

	// >5 minutes till expiration
	if(new Date(exp * 1000).getTime() > new Date().getTime() + 5 * 60 * 1000) {
		return tokens;
	}else {
		const res = await fetch(`${cognitoLoginUrl}/oauth2/token`, {
			method: "POST",
			headers: new Headers({"content-type": "application/x-www-form-urlencoded"}),
			body: Object.entries({
				"grant_type": "refresh_token",
				"client_id": clientId,
				"redirect_uri": window.location.origin,
				"refresh_token": tokens.refresh_token,
			}).map(([k, v]) => `${k}=${v}`).join("&"),
		});
		if (!res.ok) {
			throw new Error(await res.json());
		}
		const newTokens = {
			...tokens,
			...(await res.json()),
		};
		localStorage.setItem("tokens", JSON.stringify(newTokens));
		return newTokens;
	}
};

export const processLoginFlow = (cognitoLoginUrl, clientId) => async (init) => {
	const searchParams = new URL(location).searchParams;

	if (searchParams.get("code") !== null) {
		window.history.replaceState({}, document.title, "/");
		const state = searchParams.get("state");
		const codeVerifier = sessionStorage.getItem(`codeVerifier-${state}`);
		sessionStorage.removeItem(`codeVerifier-${state}`);
		if (codeVerifier === null) {
			throw new Error("Unexpected code");
		}
		const res = await fetch(`${cognitoLoginUrl}/oauth2/token`, {
			method: "POST",
			headers: new Headers({"content-type": "application/x-www-form-urlencoded"}),
			body: Object.entries({
				"grant_type": "authorization_code",
				"client_id": clientId,
				"code": searchParams.get("code"),
				"code_verifier": codeVerifier,
				"redirect_uri": window.location.origin,
			}).map(([k, v]) => `${k}=${v}`).join("&"),
		});
		if (!res.ok) {
			throw new Error(await res.json());
		}
		const tokens = await res.json();
		localStorage.setItem("tokens", JSON.stringify(tokens));

		init(tokens);
	}else {
		if (localStorage.getItem("tokens")) {
			const tokens = JSON.parse(localStorage.getItem("tokens"));
			init(tokens);
		}else {
			init(null);
		}
	}
};
