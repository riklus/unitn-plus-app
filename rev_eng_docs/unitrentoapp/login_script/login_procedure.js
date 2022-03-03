import crypto from 'crypto'
import nodeFetch from 'node-fetch'
import HttpsProxyAgent from 'https-proxy-agent'
import fetchCookie from 'fetch-cookie';
import readline from 'readline';

let cookieJar = new fetchCookie.toughCookie.CookieJar();
const fetch = fetchCookie(nodeFetch, cookieJar)
const CLIENT_SECRET = 'FplHsHYTvmMN7hvogSzf';
const CLIENT_ID = "it.unitn.icts.unitrentoapp";

const ENTRYPOINT_URL = `https://idsrv.unitn.it/sts/identity/connect/authorize?redirect_uri=unitrentoapp%3A%2F%2Fcallback&client_id=${CLIENT_ID}&response_type=code&scope=openid%20profile%20account%20email%20offline_access%20icts%3A%2F%2Funitrentoapp%2Fpreferences%20icts%3A%2F%2Fservicedesk%2Fsupport%20icts%3A%2F%2Fstudente%2Fcarriera%20icts%3A%2F%2Fopera%2Fmensa&access_type=offline&client_secret=${CLIENT_SECRET}`;

const IPHONE_HEADERS = {
  "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 15_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.0 Mobile/15E148 Safari/604.1",
  "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
  "Accept-Language": "en-GB,en;q=0.9",
  "Accept-Encoding": "gzip, deflate"
};

function sha256(buffer) {
  return crypto.createHash('sha256').update(buffer).digest();
}

function base64URLEncode(str) {
  return str.toString('base64')
      .replace(/\+/g, '-')
      .replace(/\//g, '_')
      .replace(/=/g, '');
}

function generateVerifier() {
  return base64URLEncode(crypto.randomBytes(96));
}

function generateChallenge(verifier) {
  return base64URLEncode(sha256(verifier));
}

function generateState() {
  return base64URLEncode(crypto.randomBytes(7));
}

function generateEntrypoint(code_challenge) {
  return `${ENTRYPOINT_URL}&state=${generateState()}&code_challenge=${code_challenge}&code_challenge_method=S256`;
}

function getJWT(token) {
  let [header, payload, signature] = token.split('.').map(
    x => Buffer.from(x, "base64").toString()
  );
  
  return {
    header: JSON.parse(header),
    payload: JSON.parse(payload),
    signature
  };
}

console.log("Generating authorisation challenge...");
var verifier = generateVerifier();
var challenge = generateChallenge(verifier);

let entrypointFinal = generateEntrypoint(challenge);
console.log(`Contacting identity provider at: ${entrypointFinal}`);

// Local proxy to analyse traffic
// process.env.NODE_TLS_REJECT_UNAUTHORIZED = "0"; // bypass self-signed warning
// const proxyAgent = new HttpsProxyAgent("http://127.0.0.1:8080");

let results1 = await fetch(entrypointFinal, { 
  method: "GET",
  redirect: "follow",
  headers: IPHONE_HEADERS
});

let JSESSIONID = await cookieJar.getCookieString(results1.url);

let rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout
});

// Nesting come piace a noi
rl.question("Username: ", async (username) => {
  // la password è in chiaro
  rl.question("Password: ", async (password) => {
    let params = new URLSearchParams();
    params.append('j_username', username);
    params.append('j_password', password);
    params.append('dominio', '@unitn.it');
    params.append('_eventId_proceed', '');

    // Pagina che costruisce la SAML Assertion in base al nostro JSESSIONID
    let loginURL = "https://idp.unitn.it/idp/profile/SAML2/Redirect/SSO?execution=e1s1";
    let loginFetch = await fetch(loginURL, {
      method: 'POST',
      redirect: 'follow',
      headers: { ...IPHONE_HEADERS, "Referer": "https://idp.unitn.it/idp/profile/SAML2/Redirect/SSO?execution=e1s1", "Cookie": JSESSIONID },
      body: params
    });

    // Scraping della Assertion
    let redirectForm = await loginFetch.text();
    let nextStop = "https://idsrv.unitn.it/sts/identity/saml2service/Acs";
    let signInCookies = await cookieJar.getCookieString(nextStop);

    let RelayStateRegEx = /name="(RelayState)" value="(.*?)"/gm;
    let SAMLResponseRegEx = /name="(SAMLResponse)" value="(.*?)"/gm;

    let RelayStateMatches = RelayStateRegEx.exec(redirectForm);
    let SAMLResponseMatches = SAMLResponseRegEx.exec(redirectForm);

    let RelayState = RelayStateMatches[2];
    let SAMLResponse = SAMLResponseMatches[2];
    let SAMLParams = new URLSearchParams();
    SAMLParams.append("RelayState", RelayState);
    SAMLParams.append("SAMLResponse", SAMLResponse);

    // Invio la assertion
    try {
      // Questa call fallirà inevitabilmente
      // Nessun altro redirect_uri oltre a unitrentoapp://callback viene accettato
      // Quindi quando verremo reindirizzati a unitrentoapp://callback scatterà un'eccezione
      console.log(signInCookies)
      await fetch(nextStop, {
        method: "POST",
        redirect: "follow",
        headers: { ...IPHONE_HEADERS, Cookie: signInCookies },
        body: SAMLParams
      });
    } catch(err) {
      // Catcho l'eccezione che mi dice l'URL completo che ha causato l'errore
      // Prendo l'authentication code dall'URL
      let callbackDetailsRegEx = /node-fetch cannot load unitrentoapp:\/\/callback\/\?code=(.*?)&state=(.*?)&session_state=(.*?)\. URL scheme "unitrentoapp" is not supported\./gm;
      let callbackDetails = callbackDetailsRegEx.exec(err);

      // Il mio authentication code
      let authenticationCode = callbackDetails[1];
      let authenticationState = callbackDetails[2];
      let sessionState = callbackDetails[3];
      console.log("Found Authentication Code: " + authenticationCode);
      console.log("Requesting Authorisation tokens...");

      // Preparo la chiamata per gli authorisation token
      let tokenEndpoint = "https://idsrv.unitn.it/sts/identity/connect/token";
      let tokenRequestParameters = new URLSearchParams();
      tokenRequestParameters.append("grant_type", "authorization_code");
      tokenRequestParameters.append("client_id", CLIENT_ID);
      tokenRequestParameters.append("client_secret", CLIENT_SECRET);
      tokenRequestParameters.append("redirect_uri", "unitrentoapp://callback");
      tokenRequestParameters.append("code", authenticationCode);
      tokenRequestParameters.append("code_verifier", verifier);

      // Impostazione della chiamata?
      // UniTrentoApp lo fa idk
      console.log("Setting up authorisation...");
      let tokenOptions = await nodeFetch(tokenEndpoint, {
        method: "OPTIONS",
        headers: {
          ...IPHONE_HEADERS,
          "Origin": "capacitor://localhost",
          "Access-Control-Request-Method": "POST",
          "Content-Length": 0,
          "Access-Control-Request-Headers": "unitn-culture"
        }
      });

      // Chiamata vera e propria per i token
      let tokenRequest = await nodeFetch(tokenEndpoint, {
        method: "POST",
        headers: {
          ...IPHONE_HEADERS,
          "Accept": "application/json, text/plain, */*",
          "Unitn-Culture": "it",
          "Origin": "capacitor://localhost",
          "Content-Type": "application/x-www-form-urlencoded"
        },
        body: tokenRequestParameters
      });

/*
{
  id_token: 'JWT stuff concerning identity',
  access_token: 'JWT stuff concerning authorisation',
  expires_in: 14400,
  token_type: 'Bearer',
  refresh_token: 'SHA2 stuff?'
} */
      let tokens = await tokenRequest.json();
      tokens.id_token = getJWT(tokens.id_token);
      tokens.access_token = getJWT(tokens.access_token);
      console.log(tokens.id_token);
      console.log(tokens.access_token);

      console.log(`Benvenuto ${tokens.id_token.payload.name}`);
      console.log(`• L'Identity Provider è ${tokens.id_token.payload.idp}`);
      console.log(`• Il tuo ID UniTN è ${tokens.id_token.payload.unitn_id}`);
      console.log(`• La tua identità è associata a ${tokens.id_token.payload.principal_name}`);
      console.log(`• Le autorizzazioni sono concesse all'applicazione: ${tokens.access_token.payload.client_id}`);
      console.log(`• Hai il permesso di accedere ai servizi:`);

      for(let service of tokens.access_token.payload.scope)
        console.log(`  • ${service}`)
      
      console.log(`• Questo token è valido per ${tokens.expires_in / 60} minuti`);
    }
    rl.close();
  });
});
