# Global Search Components

This directory contains components for the global search feature.

## Components

### SearchResultsPage

A full-page component that displays search results grouped by type with pagination and filtering.

**Features:**
- Displays search keyword and total result count at the top
- Loading state with skeleton screen animation
- Groups results by type (Projects, Scripts, Assets)
- Pagination controls (previous/next page)
- Advanced filtering by result type and time range
- Handles no results scenario with helpful message
- Handles error scenarios with retry button
- Cancellable search requests

**Usage:**

```dart
import 'package:openflow_app/global_search/search_results_page.dart';

// Navigate to search results page:
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => SearchResultsPage(
      query: 'search keyword',
      accessToken: session.accessToken,
      onNavigateToDetail: (type, id) {
        // Handle navigation to detail page
        // type: ResultType (project, script, asset)
        // id: String (item ID)
      },
    ),
  ),
);
```

**Parameters:**

- `query` (required): Search query keyword
- `accessToken` (required): User's access token for API authentication
- `onNavigateToDetail` (optional): Callback when a result is tapped, receives (ResultType, String id)

**API Integration:**

The component uses the following rust_api methods:
- `search(accessToken, query, resultTypes, page, pageSize, timeFrom, timeTo)`: Executes search with filters

**States:**

1. **Loading**: Shows skeleton screen with placeholder cards
2. **Error**: Displays error message with retry button
3. **No Results**: Shows "未找到匹配结果，请尝试其他关键词"
4. **Results**: Displays grouped results with pagination

**Features:**

- **Grouping**: Results are grouped by type (Projects, Scripts, Assets) with type headers
- **Pagination**: Previous/Next buttons with current page indicator
- **Filtering**: Filter dialog with result type selection and time range (time range pending implementation)
- **Highlighting**: Search keywords are highlighted in result snippets using `<mark>` tags
- **Cancellation**: Ongoing requests are cancelled when navigating away or starting a new search

**Requirements:**

This component implements task 8.1 from the global-search spec:
- Requirements: 4.1, 4.2, 4.3, 4.4, 4.7, 9.2, 9.3, 9.4

---

### SearchResultCard

A card component that displays a single search result with highlighting.

**Features:**
- Displays type icon (project/script/asset)
- Shows title and updated time
- Parses `<mark>` tags in snippet and highlights matching keywords
- Implements click navigation to detail page
- Truncates long titles and snippets with ellipsis

**Usage:**

```dart
import 'package:openflow_app/global_search/search_result_card.dart';

// In your widget:
SearchResultCard(
  result: searchResult,
  onTap: () {
    // Handle tap event
    navigateToDetail(searchResult.resultType, searchResult.id);
  },
)
```

**Parameters:**

- `result` (required): SearchResult object containing result data
- `onTap` (optional): Callback when the card is tapped

**Requirements:**

This component implements task 8.2 from the global-search spec:
- Requirements: 4.5, 4.6, 11.4

---

### SearchHistoryList

A dropdown list component that displays recent search history.

**Features:**
- Displays the most recent 5 search history entries (configurable via `maxItems`)
- Shows result count and relative time for each entry
- Allows users to click on a history entry to auto-fill and trigger search
- Provides a "Clear History" button with confirmation dialog
- Handles loading, error, and empty states gracefully

**Usage:**

```dart
import 'package:openflow_app/global_search/search_history_list.dart';

// In your widget:
SearchHistoryList(
  accessToken: session.accessToken,
  onHistorySelected: (query) {
    // Handle history item selection
    // e.g., fill search box and trigger search
    searchController.text = query;
    performSearch(query);
  },
  onClearHistory: () {
    // Handle history cleared event
    // e.g., refresh UI or show notification
  },
  maxItems: 5, // Optional, defaults to 5
)
```

**Parameters:**

- `accessToken` (required): User's access token for API authentication
- `onHistorySelected` (required): Callback when a history item is tapped, receives the query string
- `onClearHistory` (required): Callback when history is successfully cleared
- `maxItems` (optional): Maximum number of history items to display, defaults to 5

**API Integration:**

The component uses the following rust_api methods:
- `getHistory(accessToken)`: Fetches search history from the backend
- `deleteHistory(accessToken)`: Deletes all search history for the current user

**States:**

1. **Loading**: Shows a circular progress indicator while fetching history
2. **Error**: Displays error message with a retry button
3. **Empty**: Shows "暂无搜索历史" when no history exists
4. **Loaded**: Displays the list of history entries with clear button

**Time Formatting:**

The component formats timestamps relative to the current time:
- Less than 1 minute: "刚刚"
- Less than 1 hour: "X 分钟前"
- Less than 1 day: "X 小时前"
- Less than 7 days: "X 天前"
- 7 days or more: "M/D" format

**Requirements:**

This component implements task 7.2 from the global-search spec:
- Requirements: 1.6, 1.7, 5.5, 6.6

---

## Testing

All components have comprehensive unit tests located in `frontend/test/global_search/`:

- `search_results_page_test.dart`: Tests for SearchResultsPage (30 tests)
- `search_result_card_test.dart`: Tests for SearchResultCard (15 tests)
- `search_history_list_test.dart`: Tests for SearchHistoryList (9 tests)
- `global_search_bar_test.dart`: Tests for GlobalSearchBar

Run tests with:

```bash
flutter test test/global_search/
```

## Architecture

The global search feature follows a clean architecture pattern:

1. **UI Layer**: Flutter widgets in `lib/global_search/`
2. **API Layer**: Rust API bindings in `lib/rust_api/search/`
3. **Backend**: Rust + Axum API endpoints (see backend implementation)

## Data Flow

```
User Input → GlobalSearchBar → SearchResultsPage
                                      ↓
                              rust_api.search()
                                      ↓
                              Backend API
                                      ↓
                              PostgreSQL (tsvector + GIN index)
                                      ↓
                              SearchResponse
                                      ↓
                              SearchResultCard (grouped by type)
```
