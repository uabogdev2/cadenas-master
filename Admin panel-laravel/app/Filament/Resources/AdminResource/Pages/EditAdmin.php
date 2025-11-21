<?php

namespace App\Filament\Resources\AdminResource\Pages;

use App\Filament\Resources\AdminResource;
use App\Models\Admin;
use Filament\Resources\Pages\EditRecord;
use Illuminate\Validation\ValidationException;

class EditAdmin extends EditRecord
{
    protected static string $resource = AdminResource::class;

    protected function mutateFormDataBeforeSave(array $data): array
    {
        $data = AdminResource::normalizePermissions($data);

        /** @var Admin $record */
        $record = $this->getRecord();

        $currentAdminId = auth()->id();
        $isRemovingOwnPrivilege = $record->userId === $currentAdminId
            && ! ($data['permissions']['manageAdmins'] ?? false);

        if ($isRemovingOwnPrivilege) {
            $otherCount = Admin::query()
                ->where('userId', '!=', $record->userId)
                ->where('permissions->manageAdmins', true)
                ->count();

            if ($otherCount === 0) {
                throw ValidationException::withMessages([
                    'permissions.manageAdmins' => 'Vous ne pouvez pas retirer vos derniers privilèges manageAdmins.',
                ]);
            }
        }

        return $data;
    }
}

