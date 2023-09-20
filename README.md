# Bitwarden tools

Tools that help you integrate the bitwarden CLI into your scripts.

## Installation

With [μpkg](https://github.com/orbit-online/upkg)

```
upkg install -g orbit-online/bitwarden-tools@<VERSION>
```

Requires [socket-credential-cache](https://github.com/orbit-online/socket-credential-cache)
to be set up.

## Usage

### bitwarden-fields

```
Output Bitwarden item fields as bash variables
Usage:
  bitwarden-fields [options] ITEMNAME [FIELD...]

Options:
  -p --purpose PURPOSE  Specify why the master password is required.
                        The text will be appended to
                        'Enter your Bitwarden Master Password to ...'
                        [default: retrieve "$ITEMNAME"]
  --cache-for=SECONDS   Cache item with socket-credential-cache [default: 0]
  -j --json             Output as JSON instead of bash variables
  --prefix=PREFIX       Prefix variable names with supplied string
  -e                    Print 'false' on error
  --debug               Turn on bash -x
Note:
  To retrieve attachments, prefix their name with `attachment:`
  For attachment IDs use `attachmentid:`
  To retrieve all fields, omit the FIELD argument entirely
```

### bitwarden-unlock

```
Unlock Bitwarden, uses pinentry from GnuPG to prompt for the master password
Usage:
  bitwarden-unlock [options]
Options:
  -p --purpose PURPOSE  Specify why the master password is required.
                        The text will be appended to
                        'Enter your Bitwarden Master Password to ...'
  --debug               Turn on bash -x
```

### bitwarden-value

```
Retrieve a single field value from Bitwarden and output it verbatim
Usage:
  bitwarden-value [options] ITEM FIELD

Options:
  -p --purpose PURPOSE  Specify why the master password is required.
                        The text will be appended to
                        'Enter your Bitwarden Master Password to ...'
                        [default: retrieve "$FIELD" from "$ITEM"]
```

### bitwarden-ssh-askpass

```
Retrieve a single field value from Bitwarden and output it verbatim
Usage:
  bitwarden-ssh-askpass [options] [[--] ANYARGS...]

Options:
  -p --purpose PURPOSE  Specify why the master password is required.
                        The text will be appended to
                        'Enter your Bitwarden Master Password to ...'
                        [default: retrieve "$BW_FIELD" from "$BW_ITEM"]
  --item ITEM    The name of the Bitwarden item [default: $BW_ITEM]
  --field FIELD  The name of the field on the item [default: $BW_FIELD]

Note:
  You can specify both parameters through environment variables. This allows
  bitwarden-value to be used as an SSH askpass program. e.g.:
  env DISPLAY=':0.0' SSH_ASKPASS='bitwarden-value' \
    BW_SESSION='...' BW_ITEM='SSH Key' BW_FIELD='passphrase' ssh ...
  Any arguments are ignored
```

### bitwarden-cache-items

```
Cache Bitwarden multiple items in the socket-credential-cache
Usage:
  bitwarden-cache-items [options] ITEMNAME...

Options:
  --cache-for=SECONDS   Cache item for retrieval without a session [default: 0]
  -p --purpose PURPOSE  Specify why the master password is required.
                        The text will be appended to
                        'Enter your Bitwarden Master Password to ...'
                        [default: retrieve the items "$ITEMNAME"...]
```

### docker-credential-bitwarden

```
docker-credential-bitwarden - Bitwarden backing for docker logins
Usage:
  docker-credential-bitwarden get
  docker-credential-bitwarden store
  docker-credential-bitwarden erase
  docker-credential-bitwarden list

Note:
  Configure this backing in ~/.docker/config.json with
  {"credsStore": "bitwarden"}
```
