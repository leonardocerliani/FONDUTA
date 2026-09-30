
## Launching 
jupyter lab --no-browser --port=5100


## MCP server
Just look in the cline marketplace. It will install the Matlab MCP server.

The settings are then saved in `~/.vscode-server/data/User/globalStorage/saoudrizwan.claude-dev/settings`

```json
{
  "mcpServers": {
    "github.com/matlab/matlab-mcp-core-server": {
      "command": "/home/cerliani/Documents/Cline/MCP/matlab-mcp-server/matlab-mcp-server",
      "args": [
        "--matlab-root=/usr/local/MATLAB/R2022b"
      ],
      "disabled": false,
      "autoApprove": []
    }
  }
}
```


## Shortcuts:
matlab annoyingly uses shift+F7 to evaluate a selection. To remap this to a more reasonable cmd+e, install 
Karabiner (https://karabiner-elements.pqrs.org/)

and use the following as a complex modification

```json
{
    "description": "Map Cmd+E to Shift+F7 for MATLAB",
    "manipulators": [
        {
            "from": {
                "key_code": "e",
                "modifiers": {
                    "mandatory": [
                        "command"
                    ],
                    "optional": [
                        "any"
                    ]
                }
            },
            "to": [
                {
                    "key_code": "f7",
                    "modifiers": [
                        "left_shift",
                        "fn"
                    ]
                }
            ],
            "type": "basic"
        }
    ]
}
```


