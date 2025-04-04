# Debugging Linux Kernel

Setup VScode for Kernel debugging, install `bear`.

Make sure to compile the kernel with `bear`, by running `time bear -- make -j$(nproc)`.

On VScode, install `llvm-vs-code-extensions.vscode-clangd` extenstion.

Setup `.vscode/settings.json` with the following content.
```
{
	"C_Cpp.intelliSenseEngine": "disabled",
	"clangd.arguments": [
		"--compile-commands-dir=${workspaceFolder}",
		"--header-insertion=never",
		"--completion-style=detailed"
		],
	"files.exclude": {
	"**/.git": true,
	"**/.*.cmd": true,
	"**/*.o": true,
	"**/*.ko": true,
	"**/*.mod.c": true,
	"**/modules.order": true,
	"**/Module.symvers": true
	},
	"editor.insertSpaces": false,
	"editor.detectIndentation": true,
	"C_Cpp.default.intelliSenseMode": "linux-clang-x86",
	"C_Cpp.default.cStandard": "gnu11",
	"C_Cpp.default.cppStandard": "gnu++14",
	"C_Cpp.dimInactiveRegions": false
}
```

Optionally, setup `.vscode/tasks.json` with the following:
```
{
	"version": "2.0.0",
	"tasks": [
		{
			"label": "Build Kernel",
			"type": "shell",
			"command": "make defconfig && CC=\"ccache clang\" bear -- make -j$(nproc)",
			"group": "build",
			"problemMatcher": []
		},
		{
			"label": "Clean Kernel",
			"type": "shell",
			"command": "make mrproper",
			"group": "build",
			"problemMatcher": []
		}
	]
}

```

## Tips
- Setup kernel compilation environment variables by using: `export CC="ccache $COMPILER"`