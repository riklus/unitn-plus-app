# Reverse Engineering di UniTrentoApp

## Procedura di login via Shibboleth


1. L'app apre `GET https://idsrv.unitn.it/sts/identity/connect/authorize?redirect_uri=unitrentoapp%3A%2F%2Fcallback&client_id=it.unitn.icts.unitrentoapp&response_type=code&state=VxdUPcTXcR&scope=openid%20profile%20account%20email%20offline_access%20icts%3A%2F%2Funitrentoapp%2Fpreferences%20icts%3A%2F%2Fservicedesk%2Fsupport%20icts%3A%2F%2Fstudente%2Fcarriera%20icts%3A%2F%2Fopera%2Fmensa&access_type=offline&client_secret=[ VEDI client.secret.js ]&code_challenge=mlG_WUrkSDYbJYh3jkg-TH5KDL-Eb3fFTjDBmhuhPpI&code_challenge_method=S256`
  a. `code_challenge` è una stringa casuale da 43 a 128 caratteri, della quale viene calcolato il digest SHA256 (`code_challenge_method=S256`) e poi viene fatto un base64-url-encode
  b. `code_challenge_method` è `S256` oppure `plain`. UniTrentoApp usa `S256`. `plain` non testato
  c. `redirect_uri` è `unitrentoapp://callback`, quando la procedura è finita il redirect conterrà i dati necessari a completare l'autenticazione
2. <s>Catena di redirect fino a `GET https://idsrv.unitn.it/sts/identity/callback`, in cui abbiamo un codice utile a procedere, nel cookie `unitn.SignInMessage.fea8500367af23f02cd388bb55291f89`, del quale ci interessa `fea8500367af23f02cd388bb55291f89`.</s>
3. Andiamo su `GET https://idsrv.unitn.it/sts/identity/connect/authorize?redirect_uri=unitrentoapp%3A%2F%2Fcallback&client_id=it.unitn.icts.unitrentoapp&response_type=code&state=VxdUPcTXcR&scope=openid%20profile%20account%20email%20offline_access%20icts%3A%2F%2Funitrentoapp%2Fpreferences%20icts%3A%2F%2Fservicedesk%2Fsupport%20icts%3A%2F%2Fstudente%2Fcarriera%20icts%3A%2F%2Fopera%2Fmensa&access_type=offline&client_secret=[ VEDI client.secret.js ]&code_challenge=mlG_WUrkSDYbJYh3jkg-TH5KDL-Eb3fFTjDBmhuhPpI&code_challenge_method=S256`
  a. Parametri identici a prima
  b. Cookie impostati in precedenza vengono inviati
  c. Veniamo reindirizzati alla pagina indicata da `redirect_uri`, con i parametri `?code=[ CODICE DI AUTENTICAZIONE ]&state=VxdUPcTXcR&session_state=oZSD5OUHR30PFoY_I-b46YnpG-b3PlD1IRti6Oihshk.16a7cdd46a83d53138520838f1122890`. Tenere a mente `code`, verrà usato per continuare la procedura.

4. Cruciale la chiamata a `https://idsrv.unitn.it/sts/identity/connect/token`, con i parametri POST: `grant_type=authorization_code&client_id=it.unitn.icts.unitrentoapp&redirect_uri=unitrentoapp%3A%2F%2Fcallback&code=[ CODICE DI AUTENTICAZIONE ]&code_verifier=Lb5wrpnFQ5WasrAUnGBotiDF15PXE8zteseietLwkG9nZR0nyH08GmoxftvFkAFFlrWoei6dIHQiq3Pfodhqu2SXD5wZDyjvK3v8pTLNAmiuEHPfG9TzBNTp8kBkCRty&client_secret=[ VEDI client.secret.js ]`
  a. `code_verifier` è la stringa generata casualmente in precedenza, ma non crittografata, come si può notare è lunga 128 caratteri.
  b. `code` è il codice ottenuto al punto 3c
  c. Gli altri parametri rimangono invariati.

### Replicare la procedura
1. Creo il mio `code_verifier`: `aSRddkeL3j7tDn1cJXkt8fBQ3kLMTn47MLPnTqC5C9F8y0b6oL5FapgBYSTC4cSSykirOK3fLZlxCo1j3TVYK7dAoSUSKMSi09PFvK3v8pTLNAMiuEhPG9TzBnTpKF11`
2. Calcolo il digest SHA256: `89e9172458283bbb3ccb8d611a8b87c914788386b6ba478aafb76b4241ad14eb`
3. Faccio un base64-urlencoding: `ODllOTE3MjQ1ODI4M2JiYjNjY2I4ZDYxMWE4Yjg3YzkxNDc4ODM4NmI2YmE0NzhhYWZiNzZiNDI0MWFkMTRlYg`
4. Vado su browser e faccio la chiamata a Shibboleth: `https://idsrv.unitn.it/sts/identity/connect/authorize?redirect_uri=unitrentoapp%3A%2F%2Fcallback&client_id=it.unitn.icts.unitrentoapp&response_type=code&state=VxdUPcTXcR&scope=openid%20profile%20account%20email%20offline_access%20icts%3A%2F%2Funitrentoapp%2Fpreferences%20icts%3A%2F%2Fservicedesk%2Fsupport%20icts%3A%2F%2Fstudente%2Fcarriera%20icts%3A%2F%2Fopera%2Fmensa&access_type=offline&client_secret=[ VEDI client.secret.js ]&code_challenge=ODllOTE3MjQ1ODI4M2JiYjNjY2I4ZDYxMWE4Yjg3YzkxNDc4ODM4NmI2YmE0NzhhYWZiNzZiNDI0MWFkMTRlYg&code_challenge_method=S256`
5. I miei cookie sono `unitn.idsvr.session; unitn.idsrv; unitn.idsvr.clients`, devo portarmeli dietro nei vari redirect che seguono l'`authorize`, altrimenti la procedura non riconosce gli step precedenti e restituisce `There is an error determining which application you are signing into. Return to the application and try again`.
6. Inserisco le credenziali in Shibboleth e ottengo una catena di redirect che si conclude in `unitrentoapp://callback/?code=[ CODICE DI AUTENTICAZIONE ]&state=VxdUPcTXcR&session_state=FDa2A_H_LucHWctqBxQyaimau7PN387Rwwm5di8j9U4.88d987021544f218995108a4b677ce61`, dopo aver consumato la SAML Assertion.
7. Richiesta POST a `https://idsrv.unitn.it/sts/identity/connect/token` con parametri: `grant_type=authorization_code&client_id=it.unitn.icts.unitrentoapp&redirect_uri=unitrentoapp%3A%2F%2Fcallback&code=[ CODICE DI AUTENTICAZIONE ]&code_verifier=aSRddkeL3j7tDn1cJXkt8fBQ3kLMTn47MLPnTqC5C9F8y0b6oL5FapgBYSTC4cSSykirOK3fLZlxCo1j3TVYK7dAoSUSKMSi09PFvK3v8pTLNAMiuEhPG9TzBnTpKF11&client_secret=[ VEDI client.secret.js ]`, questo ci darà il Bearer token per autorizzare tutte le operazioni sulle API.
