import java.util.List;
import java.util.ArrayList;
public class NormalSzamla implements BankSzamla {
    private double egyenleg;
    private String tulajdonosNeve;
    private String szamlaszam;
    private static int szamlakSzama = 0;
    private List<Tranzakcio> tranzakciok;

    public NormalSzamla(String tulajdonosNeve) {
        this.tulajdonosNeve = tulajdonosNeve;
        this.szamlaszam = ujSzamlaSzam();
        this.tranzakciok = new ArrayList<>();
    }

    private String ujSzamlaSzam() {
        szamlakSzama++;
        return "ACC" + szamlakSzama;
    }

    public double getEgyenleg() {
        return egyenleg;
    }

    public void setEgyenleg(double egyenleg) {
        this.egyenleg = egyenleg;
    }

    @Override
    public void betesz(double osszeg) {
        this.egyenleg += osszeg;
        tranzakciok.add(new Tranzakcio(TranzakcioTipus.DEPOSIT, osszeg));
    }

    @Override
    public void kivesz(double osszeg) throws InsufficientFundsException {
        if (egyenleg >= osszeg) {
            this.egyenleg -= osszeg;
            tranzakciok.add(new Tranzakcio(TranzakcioTipus.WITHDRAW, osszeg));
        } else {
            throw new InsufficientFundsException("Nincs elegendő összeg a számlán");
        }
    }

    @Override
    public double egyenleg() {
        return egyenleg;
    }

    @Override
    public String toString() {
        StringBuilder sb = new StringBuilder();
        sb.append("Számlaszám: ").append(szamlaszam).append("\n");
        sb.append("Tulajdonos neve: ").append(tulajdonosNeve).append("\n");
        sb.append("Egyenleg: ").append(egyenleg).append(" HUF\n");
        sb.append("Tranzakciók:\n");
        for (Tranzakcio tranzakcio : tranzakciok) {
            sb.append(tranzakcio).append("\n");
        }
        return sb.toString();
    }
}
