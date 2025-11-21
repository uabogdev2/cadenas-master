<x-filament-panels::page>
    <div class="grid gap-4 md:grid-cols-3">
        @foreach ($kpis as $label => $value)
            <x-filament::section>
                <p class="text-sm text-gray-500 dark:text-gray-400">{{ \Illuminate\Support\Str::headline($label) }}</p>
                <p class="text-3xl font-semibold mt-2">{{ $value }}</p>
            </x-filament::section>
        @endforeach
    </div>

    <div class="grid gap-4 md:grid-cols-2 mt-6">
        <x-filament::section>
            <x-slot name="heading">Points</x-slot>
            <dl class="grid gap-4 grid-cols-2">
                @foreach ($points as $label => $value)
                    <div>
                        <dt class="text-xs uppercase text-gray-500">{{ \Illuminate\Support\Str::headline($label) }}</dt>
                        <dd class="text-2xl font-semibold">{{ $value }}</dd>
                    </div>
                @endforeach
            </dl>
        </x-filament::section>

        <x-filament::section>
            <x-slot name="heading">Niveaux complétés</x-slot>
            <dl class="grid gap-4 grid-cols-2">
                @foreach ($completedLevels as $label => $value)
                    <div>
                        <dt class="text-xs uppercase text-gray-500">{{ \Illuminate\Support\Str::headline($label) }}</dt>
                        <dd class="text-2xl font-semibold">{{ $value }}</dd>
                    </div>
                @endforeach
            </dl>
        </x-filament::section>
    </div>

    <div class="grid gap-4 md:grid-cols-2 mt-6">
        <x-filament::section>
            <x-slot name="heading">Top 10 points</x-slot>
            <div class="overflow-hidden ring-1 ring-gray-950/5 dark:ring-white/10 rounded-lg">
                <table class="min-w-full divide-y divide-gray-200 dark:divide-white/10">
                    <thead class="bg-gray-50 dark:bg-white/5 text-xs uppercase text-gray-500">
                        <tr>
                            <th class="px-3 py-2 text-left">Nom</th>
                            <th class="px-3 py-2 text-right">Points</th>
                        </tr>
                    </thead>
                    <tbody class="divide-y divide-gray-100 dark:divide-white/5">
                        @foreach ($topPoints as $user)
                            <tr>
                                <td class="px-3 py-2 text-sm">{{ $user->displayName ?? $user->email ?? $user->id }}</td>
                                <td class="px-3 py-2 text-sm text-right">{{ $user->points }}</td>
                            </tr>
                        @endforeach
                    </tbody>
                </table>
            </div>
        </x-filament::section>

        <x-filament::section>
            <x-slot name="heading">Top 10 niveaux complétés</x-slot>
            <div class="overflow-hidden ring-1 ring-gray-950/5 dark:ring-white/10 rounded-lg">
                <table class="min-w-full divide-y divide-gray-200 dark:divide-white/10">
                    <thead class="bg-gray-50 dark:bg-white/5 text-xs uppercase text-gray-500">
                        <tr>
                            <th class="px-3 py-2 text-left">Nom</th>
                            <th class="px-3 py-2 text-right">Niveaux</th>
                        </tr>
                    </thead>
                    <tbody class="divide-y divide-gray-100 dark:divide-white/5">
                        @foreach ($topLevels as $user)
                            <tr>
                                <td class="px-3 py-2 text-sm">{{ $user->displayName ?? $user->email ?? $user->id }}</td>
                                <td class="px-3 py-2 text-sm text-right">{{ $user->completedLevels }}</td>
                            </tr>
                        @endforeach
                    </tbody>
                </table>
            </div>
        </x-filament::section>
    </div>

    <x-filament::section class="mt-6">
        <x-slot name="heading">Analyse d'un niveau</x-slot>

        <div class="flex flex-col md:flex-row md:items-center md:justify-between gap-4 mb-4">
            <label class="text-sm font-medium text-gray-600 dark:text-gray-300">
                Niveau
                <select wire:model.live="selectedLevelId" class="mt-1 border-gray-300 dark:border-white/10 rounded-md text-sm">
                    <option value="">Tous</option>
                    @foreach ($levelsOptions as $id => $label)
                        <option value="{{ $id }}">{{ $label }}</option>
                    @endforeach
                </select>
            </label>
        </div>

        <dl class="grid gap-4 md:grid-cols-4">
            <div>
                <dt class="text-xs uppercase text-gray-500">Complétions</dt>
                <dd class="text-2xl font-semibold">{{ $levelAnalysis['completedCount'] ?? 0 }}</dd>
            </div>
            <div>
                <dt class="text-xs uppercase text-gray-500">Tentatives</dt>
                <dd class="text-2xl font-semibold">{{ $levelAnalysis['totalAttempts'] ?? 0 }}</dd>
            </div>
            <div>
                <dt class="text-xs uppercase text-gray-500">Meilleur temps (s)</dt>
                <dd class="text-2xl font-semibold">{{ $levelAnalysis['bestTime'] ?? 'N/A' }}</dd>
            </div>
            <div>
                <dt class="text-xs uppercase text-gray-500">Temps moyen (s)</dt>
                <dd class="text-2xl font-semibold">{{ $levelAnalysis['avgTime'] ?? 'N/A' }}</dd>
            </div>
        </dl>
    </x-filament::section>
</x-filament-panels::page>

