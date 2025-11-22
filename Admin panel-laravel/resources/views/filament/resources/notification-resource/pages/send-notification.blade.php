<x-filament-panels::page>
    <form wire:submit="send">
        {{ $this->form }}

        <div class="mt-4 flex justify-end">
            <x-filament::button type="submit">
                Envoyer
            </x-filament::button>
        </div>
    </form>
</x-filament-panels::page>
