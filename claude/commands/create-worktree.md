---
description: git worktree を作成して新しい tmux ウィンドウで開く
argument-hint: <branch-hint>
---

新しい git worktree を feature ブランチとして作成し、自動的に新しい tmux ウィンドウで開きます。

ブランチヒント: $ARGUMENTS

以下の手順に従ってください：

1. **前提条件の確認**:
   - git リポジトリ内にいるか確認します。リポジトリ外の場合はエラーメッセージを表示して終了します
   - tmux セッション内にいるか確認します。tmux セッション外の場合はエラーメッセージを表示して終了します
   - $ARGUMENTS にブランチヒントが指定されていない場合は、「どのようなブランチ名にしますか？」と尋ねて、ユーザーからの入力を待ちます

2. **ブランチヒントを英語に翻訳**:

   ブランチヒント "$ARGUMENTS" に日本語が含まれている場合、または標準化が必要な場合は、以下の要件に従って英語に翻訳してください：
   - 簡潔にする（最大2〜4単語）
   - 小文字のみを使用
   - スペースの代わりにハイフンを使用
   - git ブランチ名に適した形式にする（英数字とハイフンのみ）
   - すでに英語で適切にフォーマットされている場合は、そのまま使用

   翻訳例：
   - "新機能" → "new-feature"
   - "バグ修正" → "bug-fix"
   - "ログイン機能追加" → "add-login-feature"
   - "fix login bug" → "fix-login-bug"
   - "User Authentication Feature" → "user-authentication-feature"

   翻訳対象: "$ARGUMENTS"

   翻訳/整形されたブランチ名のみを応答してください。

   **日本語が含まれていた場合は、翻訳結果をユーザーに提示して確認を求めます**：
   - 「ブランチ名を "{翻訳結果}" にしますが、よろしいですか？」と尋ねます
   - ユーザーが承認した場合は、翻訳結果を `translated_name` に格納して次のステップへ進みます
   - ユーザーが修正を希望する場合は、代わりのブランチ名を入力してもらい、それを `translated_name` に格納します

3. **リポジトリ情報の取得**:

   以下の bash コマンドを実行します：

   ```bash
   # Get remote URL
   remote_url=$(git remote get-url origin)

   # Extract owner and repo name from GitHub URL
   # Supports: git@github.com:owner/repo.git and https://github.com/owner/repo.git
   if [[ "$remote_url" =~ git@github\.com:([^/]+)/([^.]+)(\.git)?$ ]]; then
     owner="${BASH_REMATCH[1]}"
     repo="${BASH_REMATCH[2]}"
   elif [[ "$remote_url" =~ https://github\.com/([^/]+)/([^/.]+)(\.git)?$ ]]; then
     owner="${BASH_REMATCH[1]}"
     repo="${BASH_REMATCH[2]}"
   else
     echo "Error: Could not parse GitHub repository from remote URL: $remote_url"
     exit 1
   fi

   # Worktree base directory
   worktree_base="$HOME/.worktrees/${owner}-${repo}"

   echo "Repository: ${owner}/${repo}"
   echo "Worktree base: ${worktree_base}"
   ```

4. **worktree の作成**:

   手順2で取得した `translated_name` を使用して以下を実行します：

   ```bash
   # Branch and worktree path
   branch_name="feature/${translated_name}"
   worktree_path="${worktree_base}/${translated_name}"

   # Check if worktree already exists
   if [[ -d "$worktree_path" ]]; then
     echo "Error: Worktree already exists at: $worktree_path"
     echo "Please use a different branch name or remove the existing worktree first"
     exit 1
   fi

   # Create base directory if it doesn't exist
   mkdir -p "$worktree_base"

   # Create git worktree
   echo "Creating worktree..."
   echo "  Branch: $branch_name"
   echo "  Path: $worktree_path"

   if ! git worktree add -b "$branch_name" "$worktree_path"; then
     echo "Error: Failed to create worktree"
     echo "The branch '$branch_name' might already exist"
     exit 1
   fi

   echo "✓ Worktree created successfully"
   ```

5. **tmux ウィンドウの作成**:

   ```bash
   # Window name (use translated_name without feature/ prefix)
   window_name="${translated_name}"

   # Create new tmux window and cd to worktree
   echo "Creating tmux window: $window_name"

   if tmux new-window -c "$worktree_path" -n "$window_name"; then
     echo "✓ Successfully created tmux window and switched to: $worktree_path"
   else
     echo "Error: Failed to create tmux window"
     echo "Worktree was created at: $worktree_path"
     echo "You can manually navigate with: cd $worktree_path"
     exit 1
   fi
   ```

6. **まとめ**:
   作成された内容のまとめを表示します：
   ```
   ✓ Worktree のセットアップが完了しました！

   ブランチ: feature/{translated_name}
   場所: {worktree_path}
   Tmux ウィンドウ: {window_name}
   ```
