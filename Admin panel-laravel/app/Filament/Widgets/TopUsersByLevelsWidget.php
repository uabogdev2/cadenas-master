<?php

namespace App\Filament\Widgets;

use App\Models\User;
use Filament\Tables;
use Filament\Tables\Columns\TextColumn;
use Filament\Widgets\TableWidget;
use Illuminate\Database\Eloquent\Builder;

class TopUsersByLevelsWidget extends TableWidget
{
    protected static ?string $heading = 'Top joueurs (niveaux complétés)';

    protected int|string|array $columnSpan = 'full';

    protected function getTableQuery(): Builder
    {
        return User::query()
            ->select(['id', 'displayName', 'email', 'completedLevels'])
            ->orderByDesc('completedLevels');
    }

    protected function getTableColumns(): array
    {
        return [
            TextColumn::make('displayName')
                ->label('Nom')
                ->formatStateUsing(fn ($state, User $record) => $state ?? $record->email ?? $record->id)
                ->searchable(),
            TextColumn::make('completedLevels')
                ->label('Niveaux')
                ->sortable()
                ->alignRight(),
        ];
    }

    public function getTableRecordsPerPage(): int|string|null
    {
        return 5;
    }

    protected function getTableEmptyStateIcon(): ?string
    {
        return 'heroicon-o-clipboard-document-check';
    }
}

