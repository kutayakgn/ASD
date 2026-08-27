using Microsoft.EntityFrameworkCore;
using YKBAfife.Models.Entities;

namespace YKBAfife.Data;

internal static partial class AfifeRelationalModelConfiguration
{
    private static void ConfigureReferenceKeys(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<AwardCategory>().HasAlternateKey(x => x.CategoryCode)
            .HasName("UQ_AwardCategories_CategoryCode");
        modelBuilder.Entity<Group>().HasAlternateKey(x => x.Code).HasName("UQ_Group_Code");
        modelBuilder.Entity<PlayStatus>().HasAlternateKey(x => x.StatusCode)
            .HasName("UQ_PlayStatuses_StatusCode");
        modelBuilder.Entity<Role>().HasAlternateKey(x => x.RoleCode).HasName("UQ_Roles_RoleCode");
    }
}
