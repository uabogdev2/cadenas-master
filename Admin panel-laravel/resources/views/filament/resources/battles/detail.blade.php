@php
    $json = fn ($payload) => json_encode($payload ?? [], JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE);
@endphp

<div class="space-y-6">
    <x-filament::section>
        <x-slot name="heading">Résumé</x-slot>
        <div class="grid gap-4 md:grid-cols-2">
            <div>
                <p class="text-xs uppercase text-gray-500 dark:text-gray-400">Statut</p>
                <p class="text-lg font-semibold">{{ $battle->status }}</p>
            </div>
            <div>
                <p class="text-xs uppercase text-gray-500 dark:text-gray-400">Mode</p>
                <p class="text-lg font-semibold">{{ $battle->mode }}</p>
            </div>
            <div>
                <p class="text-xs uppercase text-gray-500 dark:text-gray-400">Joueur 1</p>
                <p class="text-lg font-semibold">{{ $battle->playerOne->displayName ?? $battle->player1 }}</p>
                <p class="text-sm text-gray-500">Score: {{ $battle->player1Score ?? 0 }}</p>
            </div>
            <div>
                <p class="text-xs uppercase text-gray-500 dark:text-gray-400">Joueur 2</p>
                <p class="text-lg font-semibold">{{ $battle->playerTwo->displayName ?? $battle->player2 ?? 'N/A' }}</p>
                <p class="text-sm text-gray-500">Score: {{ $battle->player2Score ?? 0 }}</p>
            </div>
            <div>
                <p class="text-xs uppercase text-gray-500 dark:text-gray-400">Gagnant</p>
                <p class="text-lg font-semibold">{{ $battle->winner ?? 'Égalité' }}</p>
            </div>
            <div>
                <p class="text-xs uppercase text-gray-500 dark:text-gray-400">Résultat</p>
                <p class="text-lg font-semibold">{{ $battle->result ?? 'N/A' }}</p>
            </div>
        </div>
    </x-filament::section>

    <x-filament::section>
        <x-slot name="heading">Questions & réponses</x-slot>
        <div class="grid gap-4 md:grid-cols-2">
            <div class="md:col-span-2">
                <p class="text-xs uppercase text-gray-500 dark:text-gray-400 mb-1">Questions</p>
                <pre class="bg-gray-950/5 dark:bg-white/5 rounded p-3 text-xs overflow-auto">{{ $json($battle->questions) }}</pre>
            </div>
            <div>
                <p class="text-xs uppercase text-gray-500 dark:text-gray-400 mb-1">Réponses joueur 1</p>
                <pre class="bg-gray-950/5 dark:bg-white/5 rounded p-3 text-xs overflow-auto">{{ $json($battle->player1AnsweredQuestions) }}</pre>
            </div>
            <div>
                <p class="text-xs uppercase text-gray-500 dark:text-gray-400 mb-1">Réponses joueur 2</p>
                <pre class="bg-gray-950/5 dark:bg-white/5 rounded p-3 text-xs overflow-auto">{{ $json($battle->player2AnsweredQuestions) }}</pre>
            </div>
        </div>
    </x-filament::section>

    <x-filament::section>
        <x-slot name="heading">Trophées & chronos</x-slot>
        <div class="grid gap-4 md:grid-cols-2">
            <div>
                <p class="text-xs uppercase text-gray-500 dark:text-gray-400 mb-1">Variations de trophées</p>
                <pre class="bg-gray-950/5 dark:bg-white/5 rounded p-3 text-xs overflow-auto">{{ $json($battle->trophyChanges) }}</pre>
            </div>
            <div class="space-y-3">
                <div>
                    <p class="text-xs uppercase text-gray-500 dark:text-gray-400">Début</p>
                    <p class="text-lg font-semibold">{{ optional($battle->startTime)->format('Y-m-d H:i:s') ?? 'N/A' }}</p>
                </div>
                <div>
                    <p class="text-xs uppercase text-gray-500 dark:text-gray-400">Fin</p>
                    <p class="text-lg font-semibold">{{ optional($battle->endTime)->format('Y-m-d H:i:s') ?? 'N/A' }}</p>
                </div>
            </div>
        </div>
    </x-filament::section>
</div>

