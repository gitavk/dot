# Svelte Guidelines

Svelte-specific coding standards and best practices.

## Style & Standards

- Use **TypeScript** for type safety
- One component per file
- Keep components small and focused (under 200 lines)
- Use `$:` reactive statements for derived values
- Props should be clearly defined at the top of script section
- Use semantic HTML elements

## Component Structure

```svelte
<script lang="ts">
  // 1. Imports
  import { onMount, onDestroy } from 'svelte';
  import { writable } from 'svelte/store';
  import Button from './Button.svelte';
  
  // 2. Props (exported variables)
  export let userId: number;
  export let showDetails = false;
  export let className = '';
  
  // 3. State variables
  let user: User | null = null;
  let loading = false;
  let error: string | null = null;
  
  // 4. Reactive declarations
  $: fullName = user ? `${user.firstName} ${user.lastName}` : '';
  $: isValid = user && user.email && user.username;
  
  // 5. Functions
  async function loadUser() {
    loading = true;
    error = null;
    
    try {
      user = await fetchUser(userId);
    } catch (err) {
      error = err instanceof Error ? err.message : 'Failed to load user';
      console.error('Error loading user:', err);
    } finally {
      loading = false;
    }
  }
  
  function handleUpdate() {
    // Handle updates
  }
  
  // 6. Lifecycle hooks
  onMount(() => {
    loadUser();
    
    return () => {
      // Cleanup if needed
    };
  });
  
  onDestroy(() => {
    // Cleanup
  });
</script>

<!-- 7. Template -->
<div class="user-card {className}">
  {#if loading}
    <Spinner />
  {:else if error}
    <div class="error">{error}</div>
  {:else if user}
    <h2>{fullName}</h2>
    {#if showDetails}
      <p>{user.email}</p>
    {/if}
    <Button on:click={handleUpdate}>Update</Button>
  {:else}
    <p>No user found</p>
  {/if}
</div>

<!-- 8. Styles (scoped by default) -->
<style>
  .user-card {
    padding: 1rem;
    border-radius: 0.5rem;
    background: white;
    box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
  }
  
  .error {
    color: red;
    padding: 0.5rem;
  }
</style>
```

## Reactive Statements

```svelte
<script lang="ts">
  let count = 0;
  
  // Reactive declaration - runs when dependencies change
  $: doubled = count * 2;
  
  // Reactive statement - runs side effects
  $: if (count > 10) {
    console.log('Count is getting high!');
  }
  
  // Multiple reactive declarations
  $: {
    console.log(`Count: ${count}`);
    console.log(`Doubled: ${doubled}`);
  }
  
  // Reactive with async
  $: if (userId) {
    loadUserData(userId);
  }

  // Reactive array operations
  $: sortedItems = [...items].sort((a, b) => a.name.localeCompare(b.name));
  
  // Conditional reactive
  $: if (username && username.length > 0) {
    validateUsername(username);
  }
</script>
```

## Props and Events

```svelte
<script lang="ts">
  import { createEventDispatcher } from 'svelte';
  
  // Props with types
  export let title: string;
  export let count = 0; // Default value
  export let items: string[] = []; // Array prop
  export let user: User | null = null; // Optional object
  
  // Two-way binding prop
  export let value = '';
  
  // Event dispatcher
  const dispatch = createEventDispatcher<{
    submit: { value: string };
    cancel: void;
    update: { field: string; value: unknown };
  }>();
  
  function handleSubmit() {
    dispatch('submit', { value });
  }
  
  function handleCancel() {
    dispatch('cancel');
  }
  
  function handleFieldUpdate(field: string, newValue: unknown) {
    dispatch('update', { field, value: newValue });
  }
</script>

<input bind:value />
<button on:click={handleSubmit}>Submit</button>
<button on:click={handleCancel}>Cancel</button>

<!-- Parent component -->
<MyComponent
  {title}
  {count}
  bind:value
  on:submit={handleSubmit}
  on:cancel={handleCancel}
/>
```

## Stores

```svelte
<!-- stores.ts -->
<script lang="ts">
  import { writable, derived, readable } from 'svelte/store';
  
  // Writable store
  export const count = writable(0);
  
  // Derived store
  export const doubled = derived(count, $count => $count * 2);
  
  // Readable store (read-only)
  export const time = readable(new Date(), (set) => {
    const interval = setInterval(() => {
      set(new Date());
    }, 1000);
    
    return () => clearInterval(interval);
  });
  
  // Custom store with methods
  function createCounter() {
    const { subscribe, set, update } = writable(0);
    
    return {
      subscribe,
      increment: () => update(n => n + 1),
      decrement: () => update(n => n - 1),
      reset: () => set(0)
    };
  }
  
  export const counter = createCounter();
</script>

<!-- Using stores in components -->
<script lang="ts">
  import { count, doubled } from './stores';
  
  // Auto-subscribe with $
  $: console.log($count);
  
  function increment() {
    count.update(n => n + 1);
  }
</script>

<p>Count: {$count}</p>
<p>Doubled: {$doubled}</p>
<button on:click={increment}>Increment</button>
```

## Bindings

```svelte
<script lang="ts">
  let name = '';
  let checked = false;
  let selected = '';
  let group: string[] = [];
  let value = 50;
  
  // Element bindings
  let inputElement: HTMLInputElement;
  let divElement: HTMLDivElement;
</script>

<!-- Input bindings -->
<input bind:value={name} />
<input type="checkbox" bind:checked />
<input type="radio" bind:group value="option1" />
<input type="range" bind:value min="0" max="100" />

<!-- Select binding -->
<select bind:value={selected}>
  <option value="a">A</option>
  <option value="b">B</option>
</select>

<!-- Element binding -->
<input bind:this={inputElement} />
<div bind:this={divElement} />

<!-- Component binding -->
<ChildComponent bind:value />

<!-- Dimension bindings -->
<div
  bind:clientWidth={width}
  bind:clientHeight={height}
  bind:offsetWidth
  bind:offsetHeight
/>
```

## Control Flow

```svelte
<!-- If/Else -->
{#if condition}
  <p>True</p>
{:else if otherCondition}
  <p>Other</p>
{:else}
  <p>False</p>
{/if}

<!-- Each loop -->
{#each items as item, index (item.id)}
  <div>{index}: {item.name}</div>
{:else}
  <p>No items</p>
{/each}

<!-- Await promises -->
{#await promise}
  <p>Loading...</p>
{:then value}
  <p>Result: {value}</p>
{:catch error}
  <p>Error: {error.message}</p>
{/await}

<!-- Key blocks - force recreation when value changes -->
{#key userId}
  <UserProfile {userId} />
{/key}
```

## Transitions and Animations

```svelte
<script lang="ts">
  import { fade, fly, slide, scale } from 'svelte/transition';
  import { flip } from 'svelte/animate';
  
  let visible = true;
  let items = [1, 2, 3, 4, 5];
</script>

<!-- Transitions -->
{#if visible}
  <div transition:fade>Fades in and out</div>
  <div transition:fly={{ y: 200, duration: 300 }}>Flies in</div>
  <div in:fade out:slide>Different in/out</div>
{/if}

<!-- Animations with flip -->
{#each items as item (item)}
  <div animate:flip={{ duration: 300 }}>
    {item}
  </div>
{/each}

<!-- Custom transition -->
<script>
  function spin(node, { duration = 400 }) {
    return {
      duration,
      css: (t) => `
        transform: rotate(${t * 360}deg);
        opacity: ${t};
      `
    };
  }
</script>

<div transition:spin>Custom spin</div>
```

## Actions

```svelte
<script lang="ts">
  import type { Action } from 'svelte/action';
  
  // Custom action
  const clickOutside: Action<HTMLElement, () => void> = (node, callback) => {
    function handleClick(event: MouseEvent) {
      if (!node.contains(event.target as Node)) {
        callback();
      }
    }
    
    document.addEventListener('click', handleClick, true);
    
    return {
      destroy() {
        document.removeEventListener('click', handleClick, true);
      }
    };
  };
  
  // Tooltip action
  const tooltip: Action<HTMLElement, string> = (node, text) => {
    let tooltipEl: HTMLElement;
    
    function show() {
      tooltipEl = document.createElement('div');
      tooltipEl.textContent = text;
      tooltipEl.className = 'tooltip';
      document.body.appendChild(tooltipEl);
    }
    
    function hide() {
      tooltipEl?.remove();
    }
    
    node.addEventListener('mouseenter', show);
    node.addEventListener('mouseleave', hide);
    
    return {
      update(newText: string) {
        text = newText;
      },
      destroy() {
        node.removeEventListener('mouseenter', show);
        node.removeEventListener('mouseleave', hide);
        hide();
      }
    };
  };
</script>

<div use:clickOutside={() => console.log('Clicked outside')}>
  Content
</div>

<button use:tooltip="Click me!">Hover</button>
```

## SvelteKit Specific

```svelte
<!-- +page.svelte -->
<script lang="ts">
  import type { PageData } from './$types';
  import { goto, invalidate } from '$app/navigation';
  import { page } from '$app/stores';
  
  export let data: PageData;
  
  // Access page store
  $: console.log($page.url.pathname);
  $: console.log($page.params);
  
  async function navigateToHome() {
    await goto('/');
  }
  
  async function refreshData() {
    await invalidate('app:data');
  }
</script>

<!-- +page.ts or +page.server.ts -->
<script lang="ts">
  import type { PageLoad } from './$types';
  
  export const load: PageLoad = async ({ params, fetch }) => {
    const res = await fetch(`/api/users/${params.id}`);
    const user = await res.json();
    
    return {
      user
    };
  };
</script>

<!-- +layout.svelte -->
<script lang="ts">
  import type { LayoutData } from './$types';
  
  export let data: LayoutData;
</script>

<nav>
  <a href="/">Home</a>
  <a href="/about">About</a>
</nav>

<main>
  <slot />
</main>

<!-- +server.ts (API endpoint) -->
<script lang="ts">
  import type { RequestHandler } from './$types';
  import { json } from '@sveltejs/kit';
  
  export const GET: RequestHandler = async ({ params }) => {
    const data = await fetchData(params.id);
    return json(data);
  };
  
  export const POST: RequestHandler = async ({ request }) => {
    const body = await request.json();
    const result = await createItem(body);
    return json(result, { status: 201 });
  };
</script>
```

## Project Structure

```
src/
├── lib/
│   ├── components/
│   │   ├── ui/
│   │   │   ├── Button.svelte
│   │   │   └── Input.svelte
│   │   ├── layout/
│   │   │   ├── Header.svelte
│   │   │   └── Footer.svelte
│   │   └── features/
│   │       └── UserProfile.svelte
│   ├── stores/
│   │   ├── auth.ts
│   │   └── theme.ts
│   ├── utils/
│   │   ├── api.ts
│   │   └── validators.ts
│   ├── types/
│   │   └── user.ts
│   └── actions/
│       └── clickOutside.ts
├── routes/
│   ├── +layout.svelte
│   ├── +page.svelte
│   ├── about/
│   │   └── +page.svelte
│   └── users/
│       ├── +page.svelte
│       └── [id]/
│           ├── +page.svelte
│           └── +page.ts
├── app.html
├── app.css
└── app.d.ts
```

## Best Practices

- Use TypeScript for type safety
- Keep components under 200 lines
- Extract reusable logic into stores or utilities
- Use `$:` for reactive updates, not manual DOM manipulation
- Leverage SvelteKit for routing and SSR
- Use stores for global state
- Use `{#key}` blocks to force component recreation
- Prefer composition over prop drilling
- Use slots for flexible components
- Keep styles scoped and minimal
- Use semantic HTML
- Test components with @testing-library/svelte

## Anti-Patterns to Avoid

```svelte
<!-- ❌ Mutating props -->
<script>
  export let items = [];
  
  function addItem() {
    items.push(newItem); // BAD - mutates prop
  }
</script>

<!-- ✅ Dispatch event instead -->
<script>
  import { createEventDispatcher } from 'svelte';
  
  export let items = [];
  const dispatch = createEventDispatcher();
  
  function addItem() {
    dispatch('add', { item: newItem });
  }
</script>

<!-- ❌ Too many reactive statements -->
<script>
  $: a = b + 1;
  $: c = a + 1;
  $: d = c + 1;
  $: e = d + 1; // BAD - too complex
</script>

<!-- ✅ Combine or use derived store -->
<script>
  import { derived } from 'svelte/store';
  
  const result = derived(b, $b => $b + 4);
</script>

<!-- ❌ Large components -->
<!-- Extract into smaller, focused components instead -->
```
