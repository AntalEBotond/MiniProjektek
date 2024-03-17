import java.util.Scanner;

public class KarakterCsere {
    public static void main(String[] args) {
        Scanner scanner = new Scanner(System.in);

        System.out.println("szó:");
        String szo = scanner.nextLine();

        String csere = szo.replace('a', '*');
        System.out.println("csere utáni szó: " + csere);

        scanner.close();
    }
}
